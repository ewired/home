# Home Manager module: snapserver as a systemd user service, bound to
# PipeWire's lifecycle (restart together with
# `systemctl --user restart pipewire pipewire-pulse snapserver`).
{ config, lib, pkgs, ... }:
let
  cfg = config.services.snapcast;

  fifo = "/dev/shm/snapcast";
  format = pkgs.formats.ini { listsAsDuplicateKeys = true; };
  configFile = format.generate "snapserver.conf" cfg.settings;
in {
  options.services.snapcast = {
    enable = lib.mkEnableOption "snapserver as a user service fed by the PipeWire pipe sink";

    package = lib.mkPackageOption pkgs "snapcast" { };

    settings = lib.mkOption {
      default = { };
      description = ''
        Contents of snapserver.conf (INI sections). Written with the 0.34+
        section names (tcp-streaming.*, tcp-control.*), so no deprecation
        warnings.
      '';
      type = format.type;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.snapserver = {
      Unit = {
        Description = "Snapserver";
        # BindsTo stops snapserver with PipeWire; PartOf propagates restarts.
        After = [ "pipewire.service" "pipewire-pulse.service" ];
        BindsTo = [ "pipewire.service" "pipewire-pulse.service" ];
        PartOf = [ "pipewire.service" "pipewire-pulse.service" ];
      };
      Service = {
        ExecStart = "${lib.getExe' cfg.package "snapserver"} --config=${configFile}";
        # The sink normally creates the FIFO first; best effort for solo starts.
        ExecStartPre = "-${pkgs.coreutils}/bin/mkfifo -m 0666 ${fifo}";
        Restart = "on-failure";
        # A user manager cannot raise RT priority; ample with the 1500ms buffer.
        NoNewPrivileges = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
