{
  config,
  pkgs,
  inputs,
  unstable,
  username,
  description,
  audioNodes,
  nebulaServices,
  sambaShares,
  helix-local,
  vmSshKey,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Pinned Nix 2.35.1 via the `nix` flake input.
  nix.package = inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.nix;
  # Username-free symlink targets for the local flake inputs in flake.nix
  # (git+file:/var/lib/nix-flakes/*). Real paths are derived from `username`
  # (from private.nix), so the committed config never contains the username.
  # Create the symlinks once before the first rebuild that references them,
  # then tmpfiles keeps them managed on each activation.
  systemd.tmpfiles.rules = [
    "d /var/lib/nix-flakes 0755 root root -"
    "L+ /var/lib/nix-flakes/cinny - - - - /home/${username}/Documents/cinny"
    "L+ /var/lib/nix-flakes/helix - - - - /home/${username}/Documents/helix"
  ];
  nix.settings.trusted-users = [
    username
    "root"
  ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
    randomizedDelaySec = "45min";
  };
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "quiet"
    "zswap.enabled=0"
  ];
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=1
    blacklist xpad
  '';
  boot.blacklistedKernelModules = [ "xpad" ];
  programs.fish.enable = true;
  programs.bash.enable = true;

  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [
      networkmanager-openvpn
    ];
  };
  networking.firewall.trustedInterfaces = [ "tun0" ];
  time.timeZone = null;
  services.timesyncd.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  services.flatpak.enable = true;
  services.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverridePackages = [ pkgs.mutter ];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };
  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };
  services.xserver = {
    enable = true;

    xkb = {
      layout = "us";
      variant = "";
      options = "caps:escape";
    };
  };
  services.gnome.games.enable = false;
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
    showtime
    epiphany
    geary
    gnome-calendar
    decibels
    gnome-music
    gnome-contacts
  ];
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "foot";
  };

  programs.foot.enable = true;
  xdg.terminal-exec = {
    enable = true;
    settings = {
      GNOME = [ "foot.desktop" ];
      default = [ "foot.desktop" ];
    };
  };
  services.fwupd.enable = true;
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };
  services.zram-generator.settings."zram0".zram-resident-limit = "min(ram / 2, 16384)";
  boot.kernel.sysctl."vm.swappiness" = 150;

  # Cap IO to ~80% of measured sequential throughput (~932 MB/s) on nvme0n1
  # to prevent rogue processes from saturating disk IO
  systemd.slices."user".sliceConfig = {
    IOReadBandwidthMax = "/dev/nvme0n1 745M";
    IOWriteBandwidthMax = "/dev/nvme0n1 745M";
  };
  systemd.slices."system".sliceConfig = {
    IOReadBandwidthMax = "/dev/nvme0n1 745M";
    IOWriteBandwidthMax = "/dev/nvme0n1 745M";
  };

  systemd.coredump.extraConfig = ''
    Storage=external
    ProcessSizeMax=512M
    ExternalSizeMax=512M
  '';

  services.printing.enable = true;
  hardware.sane.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.input = {
    General = {
      UserspaceHID = true;
    };
  };
  hardware.xone.enable = true;
  programs.steam = {
    enable = true;
    package = unstable.steam;
    extraPackages = [ unstable.gamescope ];
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    extraConfig.pipewire."10-combine-sink" = {
      "context.modules" = [
        {
          name = "libpipewire-module-combine-stream";
          args = {
            "combine.mode" = "sink";
            "node.name" = "unified_output";
            "node.description" = "Unified Sink (Speakers + Headphones)";
            "combine.latency-compensate" = false;
            "combine.props" = {
              "audio.position" = [ "FL" "FR" ];
            };
            "stream.props" = {
              "stream.dont-remix" = true;
            };
            "stream.rules" = [
              {
                matches = [{
                  "media.class" = "Audio/Sink";
                  "node.name" = audioNodes.hdmi;
                }];
                actions = {
                  "create-stream" = {
                    "combine.audio.position" = [ "FL" "FR" ];
                    "audio.position" = [ "FL" "FR" ];
                  };
                };
              }
              {
                matches = [{
                  "media.class" = "Audio/Sink";
                  "node.name" = audioNodes.bluetooth;
                }];
                actions = {
                  "create-stream" = {
                    "combine.audio.position" = [ "FL" "FR" ];
                    "audio.position" = [ "FL" "FR" ];
                  };
                };
              }
              {
                matches = [{
                  "media.class" = "Audio/Sink";
                  "node.name" = audioNodes.headset;
                }];
                actions = {
                  "create-stream" = {
                    "combine.audio.position" = [ "FL" "FR" ];
                    "audio.position" = [ "FL" "FR" ];
                  };
                };
              }
            ];
          };
        }
      ];
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    inherit description;
    extraGroups = [
      "networkmanager"
      "wheel"
      "scanner"
      "input"
      "libvirtd"
    ];
    shell = pkgs.fish;
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      cantarell-fonts
      pixel-code
      noto-fonts
      noto-fonts-cjk-sans
      liberation_ttf
      fira-code
      fira-code-symbols
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
    ];
  };

  programs.direnv.enable = true;

  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    helix-local.packages.${pkgs.stdenv.hostPlatform.system}.default
    # helix
    nil
    chezmoi
    cloud-utils
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.nix-index-database.packages.${pkgs.stdenv.hostPlatform.system}.comma-with-db
    wl-clipboard
    gnomeExtensions.caffeine
    gnomeExtensions.bing-wallpaper-changer
    gnomeExtensions.hot-edge
    gnomeExtensions.appindicator
    gnomeExtensions.burn-my-windows
    gnomeExtensions.tiling-shell
    resources
    meld
    ripgrep
    fd
    zip
    unzip
    xxd
    bubblewrap
    libnotify
    jq
    gettext
    glib.dev
    glib
    bc
    celluloid
    cava
    ffmpeg-headless
    ffmpegthumbnailer
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-vaapi
    pavucontrol
    ncdu
    bottom
    aria2
    wget2
    mesa-demos
    libimobiledevice
    ifuse
    wget
    python3Minimal
    gjs
    zenity
    (writeShellScriptBin "sudo-askpass" ''
      exec ${zenity}/bin/zenity --password --title="sudo authentication"
    '')
  ];
  environment.variables = {
    GST_PLUGIN_PATH = "/run/current-system/sw/lib/gstreamer-1.0/";
  };
  programs.git.enable = true;
  services.openssh.enable = true;

  # Graphical sudo authentication so agents can authorize privileged commands
  # via a GUI password prompt. Agents should use `sudo -A`; sudo also falls
  # back to the askpass helper automatically when no tty is attached.
  security.polkit.enable = true;
  security.sudo.extraConfig = ''
    Defaults env_keep += "SUDO_ASKPASS"
  '';
  environment.sessionVariables = {
    SUDO_ASKPASS = "/run/current-system/sw/bin/sudo-askpass";
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = sambaShares;
  };
  services.samba-wsdd.enable = true;
  services.samba.nmbd.enable = true;
  system.stateVersion = "25.11"; # Did you read the comment?
   programs.nix-ld = {
     enable = true;
     libraries = with pkgs; [
       stdenv.cc.cc.lib
       alsa-lib
       libx11
       libxext
       libxcb
       fribidi
       fontconfig
       zlib
       freetype
       libdrm
       harfbuzz
       libgpg-error
       libGL
       libglvnd
       libgbm
       e2fsprogs
       gmp
       vulkan-loader
       pipewire.jack
       gtk3
       glib
       libxtst
       gtk4
       cairo
       pango
       gdk-pixbuf
       libadwaita
     ];
   };
  services.usbmuxd.enable = true;
  virtualisation.podman.enable = true;

  # --- KVM/libvirt: declaratively provision a Fedora guest --------------------
  # libvirtd runs qemu:///system with UEFI (OVMF) + a virtual TPM. The guest
  # is provisioned via cloud-init (NoCloud seed) by the one-shot service below;
  # it is idempotent once the domain exists. Memory ballooning is disabled
  # (--memballoon model=none) so the guest's RAM is pinned and never reclaimed.
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  programs.obs-studio.enable = true;
  programs.ssh = {
    extraConfig = ''
      Host *
          SetEnv TERM=xterm-256color
    '';
  };

  systemd.services = pkgs.lib.mkMerge [
    nebulaServices
    {
      # Download the Fedora 44 cloud image, build the cloud-init seed, and
      # create/start the libvirt domain. A no-op once `fedora` exists. RAM is
      # pinned at 24 GiB (no balloon) and the domain does not autostart, so the
      # guest stays off after a host reboot until started manually. Perf tuning
      # baked into virt-install: host-passthrough CPU with the host's real
      # 1S/8C/2T topology (npt/svm off), 2 iothreads pinned to the last vCPUs,
      # 4 virtio queues on both disk and NIC, and a native TSC fallback clock.
      fedora-vm-provision = {
        description = "Provision Fedora 44 KVM guest via cloud-init";
        after = [
          "libvirtd.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        requires = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        path = with pkgs; [
          qemu_kvm
          cloud-utils
          virt-manager
          libvirt
          curl
          coreutils
          gnugrep
          gnused
          gawk
          iproute2
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail

          VM_NAME="fedora"
          IMG_DIR="/var/lib/libvirt/images"
          BASE_FILE="Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"
          BASE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images"
          BASE="$IMG_DIR/$BASE_FILE"
          CKFILE="$IMG_DIR/Fedora-Cloud-44-1.7-x86_64-CHECKSUM"
          DISK="$IMG_DIR/fedora.qcow2"
          SEED="$IMG_DIR/fedora-seed.iso"
          DISK_SIZE="40G"

          if virsh domstate "$VM_NAME" >/dev/null 2>&1; then
            echo "VM $VM_NAME already exists; nothing to do."
            exit 0
          fi

          mkdir -p "$IMG_DIR"

          if [ ! -f "$BASE" ]; then
            echo "Downloading Fedora 44 cloud image..."
            curl -fL -o "$BASE" "$BASE_URL/$BASE_FILE"
            curl -fL -o "$CKFILE" "$BASE_URL/Fedora-Cloud-44-1.7-x86_64-CHECKSUM"
            expected=$(grep -F "$BASE_FILE" "$CKFILE" 2>/dev/null | grep -oE '[0-9a-f]{64}' | head -1 || true)
            actual=$(sha256sum "$BASE" | awk '{print $1}')
            if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
              echo "ERROR: checksum mismatch for $BASE" >&2
              exit 1
            fi
            echo "Checksum verified."
          fi

          if [ ! -f "$DISK" ]; then
            echo "Creating guest disk from base image..."
            cp "$BASE" "$DISK"
            qemu-img resize "$DISK" "$DISK_SIZE"
          fi

          echo "Building cloud-init seed ISO..."
          # NoCloud datasource files baked into the seed ISO. The default
          # `fedora` user comes from the cloud image; SSH is key-only.
          cloud-localds "$SEED" \
            "${pkgs.writeText "fedora-user-data" ''
              #cloud-config
              hostname: fedora
              disable_root: true
              ssh_pwauth: false
              users:
                - name: fedora
                  sudo: ALL=(ALL) NOPASSWD:ALL
                  shell: /bin/bash
                  ssh_authorized_keys:
                    - ${vmSshKey}
              package_upgrade: false
            ''}" \
            "${pkgs.writeText "fedora-meta-data" ''
              instance-id: fedora-vm
              local-hostname: fedora
            ''}"

          echo "Ensuring libvirt default (NAT) network is active..."
          virsh net-start default 2>/dev/null || true
          virsh net-autostart default 2>/dev/null || true

          echo "Creating and starting VM $VM_NAME..."
          VCPUS=$(nproc)
          CORES=$((VCPUS / 2))
          virt-install \
            --name "$VM_NAME" \
            --memory 24576 \
            --vcpus "$VCPUS" \
            --cpu "host-passthrough,topology.sockets=1,topology.dies=1,topology.cores=$CORES,topology.threads=2,-npt,-svm" \
            --iothreads 2 \
            --cputune "iothreadpin0.iothread=1,iothreadpin0.cpuset=$((VCPUS-2)),iothreadpin1.iothread=2,iothreadpin1.cpuset=$((VCPUS-1))" \
            --clock offset=utc,timer0.name=rtc,timer0.tickpolicy=catchup,timer1.name=pit,timer1.tickpolicy=delay,timer2.name=hpet,timer2.present=no,timer3.name=tsc,timer3.mode=native \
            --memballoon model=none \
            --disk "path=$DISK,format=qcow2,bus=virtio,driver.queues=4,driver.iothread=1" \
            --disk "path=$SEED,device=cdrom" \
            --network "network=default,model=virtio,driver.queues=4" \
            --os-variant fedora42 \
            --boot uefi \
            --import --noautoconsole
        '';
      };
    }
  ];
}
