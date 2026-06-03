# nanopi-r6s-boot.nix - Minimal bootable NanoPi R6S configuration
# This module contains ONLY what's needed to boot the hardware
{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules/rockchip-image.nix
    ../modules/rknpu.nix
  ];

  # Essential kernel modules for NanoPi R6S hardware
  boot.initrd.availableKernelModules = [
    "dw_mmc_rockchip"  # Rockchip SD/eMMC controllers
    "usbnet" "cdc_ether" "rndis_host" # USB networking (for recovery/debug)
    "r8169"  # RTL8125 2.5GbE (uses r8169 driver)
  ];

  # Rockchip board configuration - hardware specific
  rockchip = {
    enable = true;

    # NanoPi R6S specific hardware
    uboot.package = pkgs.ubootNanopiR6S;
    deviceTree = "rockchip/rk3588s-nanopi-r6s.dtb";

    # Console configuration for NanoPi R6S
    # Debug UART is on the 12-pin FPC connector (active, active low, active, active, active, active, active, active, active, active, active, active)
    console = {
      earlycon = "uart8250,mmio32,0xfeb50000";  # Keep this for very early boot
      console = "ttyS2,1500000";  # Serial console on debug UART
    };

    # Default image variants (can be overridden by consumers)
    image.buildVariants = {
      full = lib.mkDefault true;       # eMMC image with U-Boot
      sdcard = lib.mkDefault true;     # SD card image
      ubootOnly = lib.mkDefault false; # U-Boot only (disabled by default)
    };
  };

  # Bump the eMMC from HS200 to HS400 Enhanced Strobe. The RK3588S controller
  # and the on-board eMMC both support HS400ES (and the data-strobe pin is
  # already pinmuxed), but the stock mainline DT only enables HS200. We apply a
  # small device-tree overlay rather than forking the kernel's DT source. The
  # top-level `filter` keeps overlay processing scoped to the R6S DTB; `name`
  # (which selects the DTB at boot) is set by modules/rockchip-image.nix from
  # rockchip.deviceTree above.
  hardware.deviceTree = {
    filter = "rk3588s-nanopi-r6s.dtb";
    overlays = [
      {
        name = "rk3588s-nanopi-r6s-emmc-hs400es";
        filter = "rk3588s-nanopi-r6s.dtb";
        dtsFile = ./overlays/rk3588s-nanopi-r6s-emmc-hs400es.dts;
      }
    ];
  };


  # Essential Nix configuration for flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # System version (consumers should override this)
  system.stateVersion = lib.mkDefault "25.11";

  # Ensure console is available
  console.enable = lib.mkDefault true;
}
