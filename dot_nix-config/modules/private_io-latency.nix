# Interactive IO protection via the BFQ scheduler.
#
# Replaces the previous IOReadBandwidthMax/IOWriteBandwidthMax slice caps:
# those were throughput throttles with no priority, so they throttled the
# interactive victims in user.slice along with the offending builds, and did
# nothing about queue-depth-induced latency. BFQ does proportional-share
# scheduling with interactive/soft-realtime detection, so media players and
# the session stay responsive while background builds (Rust et al.) yield
# only under actual contention.
{ config, lib, ... }:

let
  device = "nvme0n1";
in
{
  # bfq is a module on recent kernels; load it before the root device is
  # used so the scheduler is available from early boot.
  boot.initrd.kernelModules = [ "bfq" ];

  # Select BFQ on the NVMe device. udev applies this on boot and replug.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="${device}", ATTR{queue/scheduler}="bfq"
  '';

  # BFQ defaults to low_latency=1 (interactive + soft realtime heuristics);
  # asserted here so a future kernel default change doesn't silently regress.
  systemd.services."bfq-tune" = {
    description = "Tune BFQ scheduler on ${device}";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      echo 1 > /sys/block/${device}/queue/iosched/low_latency
    '';
  };

  # Keep dirty pagecache small so a burst of build writes (cargo, rustc)
  # can't accumulate hundreds of MB and then flush as one long sync blob
  # that stalls everything. 128MB is plenty for throughput on this drive.
  boot.kernel.sysctl = {
    "vm.dirty_bytes" = 134217728;
    "vm.dirty_background_bytes" = 33554432;
  };
}
