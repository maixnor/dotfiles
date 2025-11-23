{ config, lib, pkgs, ... }:

{
  # Disable power-profiles-daemon as it conflicts with auto-cpufreq
  services.power-profiles-daemon.enable = false;
  
  # auto-cpufreq provides intelligent CPU frequency scaling
  # It's more responsive than static powersave governor while still saving power
  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "powersave";
        scaling_min_freq = 800000;  # Allow CPU to go low when idle
        scaling_max_freq = 3500000; # But still allow turbo when needed
        turbo = "auto";             # Enable turbo on demand
        enable_thresholds = true;
        start_threshold = 20;
        stop_threshold = 80;
      };
      charger = {
        governor = "performance";
        scaling_min_freq = 1000000;
        scaling_max_freq = 4500000;
        turbo = "auto";
        enable_thresholds = false;
      };
    };
  };

  # Laptop mode for aggressive power saving
  powerManagement = {
    enable = true;
    powertop.enable = true;  # Enable PowerTOP's auto-tune on boot
  };

  # Aggressive power saving kernel parameters
  boot.kernelParams = [
    # Intel GPU power saving
    "i915.enable_fbc=1"           # Enable framebuffer compression
    "i915.enable_psr=2"           # Enable Panel Self Refresh (PSR2 for better savings)
    "i915.fastboot=1"             # Faster boot, less power waste
    
    # NVMe power saving (APST = Autonomous Power State Transition)
    "nvme_core.default_ps_max_latency_us=5500"
    
    # General power saving
    "pcie_aspm.policy=powersupersave"  # Aggressive PCIe power management
  ];

  # Enable runtime power management for devices
  boot.extraModprobeConfig = ''
    # Audio power saving
    options snd_hda_intel power_save=1
    options snd_ac97_codec power_save=1
    
    # Wireless power saving
    options iwlwifi power_save=1
    options iwldvm force_cam=0
    options iwlmvm power_scheme=3
    
    # Enable SATA link power management
    options ahci.force_lpm=med_power_with_dipm
  '';

  # Services for runtime power management
  services.udev.extraRules = ''
    # Runtime PM for PCI devices
    ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
    
    # Runtime PM for USB devices (excluding input devices to avoid lag)
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
    
    # Runtime PM for SCSI devices (SSDs/NVMe)
    ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="med_power_with_dipm"
  '';

  # System power management settings
  systemd.services.powersave-tweaks = {
    description = "Additional power saving tweaks";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Enable laptop mode (more aggressive writeback)
      echo 5 > /proc/sys/vm/laptop_mode
      
      # Increase dirty writeback time (less frequent disk writes)
      echo 1500 > /proc/sys/vm/dirty_writeback_centisecs
      
      # Audio power saving
      echo 1 > /sys/module/snd_hda_intel/parameters/power_save
      
      # Disable NMI watchdog (saves power, can impact debugging)
      echo 0 > /proc/sys/kernel/nmi_watchdog
      
      # SATA link power management
      for i in /sys/class/scsi_host/host*/link_power_management_policy; do
        [ -f "$i" ] && echo med_power_with_dipm > "$i"
      done
      
      # Enable controller power management for NVMe
      for i in /sys/bus/pci/devices/*/power/control; do
        echo auto > "$i"
      done
      
      # CPU energy performance preference (balance performance and power)
      if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
          echo balance_power > "$cpu" 2>/dev/null || true
        done
      fi
    '';
  };

  # Brightness control for power saving
  programs.light.enable = true;
  
  # Enable TLP as alternative (COMMENTED OUT - conflicts with auto-cpufreq)
  # Uncomment and disable auto-cpufreq if you prefer TLP instead
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #     
  #     CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
  #     CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
  #     
  #     CPU_MIN_PERF_ON_AC = 0;
  #     CPU_MAX_PERF_ON_AC = 100;
  #     CPU_MIN_PERF_ON_BAT = 0;
  #     CPU_MAX_PERF_ON_BAT = 60;
  #     
  #     START_CHARGE_THRESH_BAT0 = 75;
  #     STOP_CHARGE_THRESH_BAT0 = 80;
  #     
  #     WIFI_PWR_ON_BAT = "on";
  #     WOL_DISABLE = "Y";
  #     
  #     SOUND_POWER_SAVE_ON_BAT = 1;
  #     
  #     RUNTIME_PM_ON_BAT = "auto";
  #   };
  # };
}
