# Battery level on the fish right prompt, shown only while discharging: a weak
# charger that cannot keep up still leaves status = Discharging, so we key on
# the battery's own status rather than AC presence. Reads sysfs directly, so no
# daemon is needed.
{ config, lib, ... }:
let
  cfg = config.services.batteryPrompt;

  # `read` is a builtin, so no process is forked per attribute. The \uXXXX
  # escapes are Nerd Font battery glyphs.
  promptBody = ''
    set -l bat
    set -l ac_online 0
    for ps in /sys/class/power_supply/*
        read -l kind < $ps/type
        switch $kind
            case Battery
                set -q bat[1]; or set bat $ps
            case Mains
                read -l online < $ps/online
                test "$online" = 1; and set ac_online 1
        end
    end
    test -n "$bat"; or return

    set -l state Unknown
    test -r $bat/status; and read -l state < $bat/status
    switch $state
        case Discharging
            # Show even if a weak charger is attached.
        case Charging Full 'Not charging'
            return
        case '*'
            test "$ac_online" = 1; and return
    end

    read -l capacity < $bat/capacity
    string match -qr '^\d+$' -- $capacity; or return

    set -l icon \uf244
    if test $capacity -ge 86
        set icon \uf240
    else if test $capacity -ge 61
        set icon \uf241
    else if test $capacity -ge 36
        set icon \uf242
    else if test $capacity -ge 11
        set icon \uf243
    end

    set -l color green
    if test $capacity -le 15
        set color red
    else if test $capacity -le 40
        set color yellow
    end

    echo -n -s (set_color $color) $icon ' ' $capacity'%' (set_color normal)
  '';
in {
  options.services.batteryPrompt.enable =
    lib.mkEnableOption "battery level in the fish right prompt while discharging";

  config = lib.mkIf cfg.enable {
    programs.fish.functions.fish_right_prompt = {
      description = "Battery level while discharging";
      body = promptBody;
    };
  };
}
