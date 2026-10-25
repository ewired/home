# NixOS module: PipeWire plumbing for snapserver (the server itself is the
# Home Manager user service in modules/snapcast.nix).
{ config, lib, pkgs, ... }:
let
  cfg = config.services.snapcast-pipewire;
in {
  options.services.snapcast-pipewire = {
    enable = lib.mkEnableOption "PipeWire pipe sink and EQ filter chain feeding snapserver";

    # Must match snapserver's ports.
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open TCP ports 1704/1705/1780 for snapserver. No auth; LAN + VPN only.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      # Format must match the snapserver stream sampleformat. may-pause=true
      # so a full FIFO deactivates the sink instead of spinning on EAGAIN.
      extraConfig.pipewire-pulse."40-snapcast-sink" = {
        "pulse.cmd" = [
          {
            cmd = "load-module";
            args = "module-pipe-sink file=/dev/shm/snapcast sink_name=Snapcast format=s16le rate=48000 channels=2 sink_properties=\"tunnel.may-pause=true\"";
          }
        ];
      };

      # Phone-leg EQ: L+R downmix to dual mono, 90Hz-15kHz band limit.
      # A graph output port can only be bound once, hence the copy nodes.
      extraConfig.pipewire."05-snapcast-filter" = {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            args = {
              "node.description" = "Snapcast EQ (mono downmix + band limit)";
              "filter.graph" = {
                nodes = [
                  {
                    type = "builtin";
                    name = "mono";
                    label = "mixer";
                    control = {
                      "Gain 1" = 0.5;
                      "Gain 2" = 0.5;
                    };
                  }
                  {
                    type = "builtin";
                    name = "highpass";
                    label = "bq_highpass";
                    control = {
                      "Freq" = 90.0;
                      "Q" = 0.707;
                      "Gain" = 0.0;
                    };
                  }
                  {
                    type = "builtin";
                    name = "lowpass";
                    label = "bq_lowpass";
                    control = {
                      "Freq" = 15000.0;
                      "Q" = 0.707;
                      "Gain" = 0.0;
                    };
                  }
                  {
                    type = "builtin";
                    name = "dup_left";
                    label = "copy";
                  }
                  {
                    type = "builtin";
                    name = "dup_right";
                    label = "copy";
                  }
                ];
                links = [
                  { output = "mono:Out"; input = "highpass:In"; }
                  { output = "highpass:Out"; input = "lowpass:In"; }
                  { output = "lowpass:Out"; input = "dup_left:In"; }
                  { output = "lowpass:Out"; input = "dup_right:In"; }
                ];
                inputs = [ "mono:In 1" "mono:In 2" ];
                outputs = [ "dup_left:Out" "dup_right:Out" ];
              };
              "audio.channels" = 2;
              "audio.position" = [ "FL" "FR" ];
              # Quoted keys: not nested under capture/playback.
              "capture.props" = {
                "node.name" = "effect_input.snapcast_eq";
                "media.class" = "Audio/Sink";
              };
              "playback.props" = {
                "node.name" = "effect_output.snapcast_eq";
                "node.passive" = true;
                # WirePlumber relinks this to the pipe sink whenever it appears.
                "target.object" = "Snapcast";
              };
            };
          }
        ];
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ 1704 1705 1780 ];
  };
}
