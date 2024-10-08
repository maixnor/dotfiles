{ config, lib, pkgs, ... }:
{

  # Opengl
  hardware.graphics = {
    enable = true;

    # Install additional packages that improve graphics performance and compatibility.
    extraPackages = with pkgs; [
      libvdpau-va-gl
      nvidia-vaapi-driver
      vaapiVdpau
      vulkan-validation-layers
    ];
  };

  services.xserver.videoDrivers = ["nvidia"];
  boot.kernelParams = [ "nvidia_drm.modeset=1" "nvidia-drm.fbdev=1" "module_blacklist=i915" ];

  hardware.nvidia = {
    # Required
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    #forceFullCompositionPipeline = true;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;
    nvidiaSettings = true;

    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # Set environment variables related to NVIDIA graphics
  environment.variables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Packages related to NVIDIA graphics
  environment.systemPackages = with pkgs; [
    clinfo
    gwe
    nvtopPackages.nvidia
    virtualglLib
    vulkan-loader
    vulkan-tools
  ];

}
