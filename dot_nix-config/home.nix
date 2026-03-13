{
  config,
  lib,
  pkgs,
  unstable,
  voxtype,
  llamaCpp,
  herdr,
  cinny-local,
  gws,
  username,
  ...
}: {
  imports = [
    voxtype.homeManagerModules.default
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";
  home.sessionVariables = {
    PATH = "$HOME/.local/bin:$HOME/bin:$HOME/go/bin:$HOME/.bun/bin:$PATH";
  };
  programs = {
    bash.enable = true;
    fish = {
      enable = true;
      interactiveShellInit = ''
        bass "set -a; source ~/.env; set +a" 2>/dev/null
        set -gx EDITOR hx
      '';
      plugins = [
        {
          name = "bass";
          src = pkgs.fishPlugins.bass.src;
        }
      ];
    };

    home-manager.enable = true;
    mise = {
      enable = true;
      package = unstable.mise;
    };
    jujutsu = {
      enable = true;
      package = unstable.jujutsu;
    };
    difftastic = {
      enable = true;
      package = unstable.difftastic;
    };
    jjui = {
      enable = true;
      package = unstable.jjui;
    };
    uv.enable = true;
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
    };
    go.enable = true;
    fzf.enable = true;
    zoxide.enable = true;

    tmux = {
      enable = true;
      mouse = true;
      historyLimit = 100000;
      terminal = "foot";
      keyMode = "vi";
      customPaneNavigationAndResize = true;
      escapeTime = 10;
      extraConfig = ''
        set -sg terminal-overrides ",*:RGB"
        bind -r Tab select-pane -t :.+
        bind P run-shell "wl-paste -n | tmux load-buffer - ; tmux paste-buffer"
        bind '"' split-window -v -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"
        set -g pane-border-status top
        set -g pane-border-format "#{s|$HOME|~|:pane_current_path}"
        set -g window-status-format "#I:#{=6:#{b:pane_current_path}}~#W#F"
        set -g window-status-current-format "#I:#{=6:#{b:pane_current_path}}~#W#F"
        set -g extended-keys on
        set -g extended-keys-format csi-u
        set -g set-titles on
        set -g set-titles-string "tmux: #S:#W"
      '';
    };

  };

  programs.voxtype = {
    enable = true;
    package = voxtype.packages.x86_64-linux.onnx;
    service.enable = true;
    settings = {
      engine = "cohere";
      cohere.model = "cohere-transcribe-q4f16";
      cohere.language = "en";
      cohere.threads = 8;
      hotkey.enabled = true;
      hotkey.key = "SCROLLLOCK";
      output.mode = "type";
      output.driver_order = ["dotool"];
      output.type_delay_ms = 0;
      output.notification.on_transcription = false;
    };
  };

  systemd.user.services.voxtype = {
    Install.WantedBy = lib.mkForce [ ];
  };

  xdg.desktopEntries.foot-herdr = {
    name = "Foot (herdr)";
    exec = ''foot -- fish -c "herdr"'';
    terminal = false;
    categories = [
      "System"
      "TerminalEmulator"
    ];
  };
  xdg.desktopEntries."wrap-ytdl" = {
    name = "WrapGuard yt-dlp";
    exec = "/home/${username}/Videos/ytdl/wrapguard.sh";
    settings.Path = "/home/${username}/Videos/ytdl";
    terminal = true;
    categories = [
      "AudioVideo"
      "Utility"
    ];
  };
  dconf.settings = {
    "org/gnome/shell/keybindings" = {
      switch-to-application-1 = [ ];
      switch-to-application-2 = [ ];
      switch-to-application-3 = [ ];
      switch-to-application-4 = [ ];
      switch-to-application-5 = [ ];
      switch-to-application-6 = [ ];
      switch-to-application-7 = [ ];
      switch-to-application-8 = [ ];
      switch-to-application-9 = [ ];
    };
    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      switch-to-workspace-5 = [ "<Super>5" ];
      switch-to-workspace-6 = [ "<Super>6" ];
      switch-to-workspace-7 = [ "<Super>7" ];
      switch-to-workspace-8 = [ "<Super>8" ];
      switch-to-workspace-9 = [ "<Super>9" ];
    };
  };

  home.packages = [
    herdr.packages.x86_64-linux.default
    cinny-local.packages.x86_64-linux.cinny
    gws.packages.x86_64-linux.default
    unstable.devenv
    unstable.deno
    unstable.bun
    unstable.wgcf
    unstable.dbmate
    unstable.just
    unstable.mergiraf
    voxtype.packages.x86_64-linux.osd-gtk4
    pkgs.gcc
    pkgs.gnumake
    llamaCpp.packages.x86_64-linux.vulkan
    unstable.vscode-langservers-extracted
    unstable.postgresql_18
    unstable.delta
    (pkgs.rustPlatform.buildRustPackage rec {
      pname = "jjc";
      version = "0.1.0";
      src = pkgs.fetchgit {
        url = "https://tangled.sh/akashina.tngl.sh/jjc";
        rev = "bb71fdcd704e8bf4ddfac9ac0e3a036cab441b2c";
        hash = "sha256-1ak6NCyjtQBipgCtHjhGZduu3tqyzS4vbdprj2UJ9/g=";
      };
      cargoHash = "sha256-ER1oW/y8IVFqJ+UxBpE1f6OiZUDbt05kbwxMD4fc6jM=";
    })
    (pkgs.buildGoModule {
      pname = "wrapguard";
      version = "1.3.2";
      src = pkgs.fetchFromGitHub {
        owner = "puzed";
        repo = "wrapguard";
        rev = "v1.3.2";
        hash = "sha256-B2JHvxggHaj+MuR39p0a5BIuLt66+gbpBnF87mhbssU=";
      };
      vendorHash = "sha256-eS4D494IFFNVvp9Do2e1zCU1DWAInigyK8EakfLqO6U=";
      doCheck = false;
      nativeBuildInputs = [ pkgs.gcc ];
      postInstall = ''
        $CC -shared -fPIC -Wall -Wpedantic -O2 lib/intercept.c -ldl \
          -o "$out/bin/libwrapguard.so"
      '';
      meta = with pkgs.lib; {
        description = "Userspace WireGuard proxy for transparent network tunneling";
        homepage = "https://github.com/puzed/wrapguard";
        license = licenses.mit;
        mainProgram = "wrapguard";
      };
    })
  ];

  # TODO: use a nix input for hashcards
  systemd.user.services.hashcards-drill = {
    Unit = {
      Description = "Hashcards drill";
      RefuseManualStart = true;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '~/.cargo/bin/hashcards drill --card-limit 10 ~/Documents/Cards'";
      TimeoutStartSec = "3h";
    };
  };

  systemd.user.timers.hashcards-drill = {
    Unit = {
      Description = "Run hashcards drill hourly";
    };
    Timer = {
      OnCalendar = "hourly";
      DeferReactivation = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  services.podman = {
    enable = true;
    containers.hermes = {
      image = "nousresearch/hermes-agent:latest";
      network = "host";
      volumes = [ "%h/.hermes:/opt/data" ];
      environmentFile = [ "%h/.hermes.env" ];
      ports = [ "127.0.0.1:8642:8642" "127.0.0.1:9119:9119" ];
      environment = {
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = "127.0.0.1";
        HERMES_DASHBOARD = "1";
        HERMES_DASHBOARD_HOST = "127.0.0.1";
      };
      extraPodmanArgs = [ "--tty" ];
      autoStart = true;
    };
  };
}
