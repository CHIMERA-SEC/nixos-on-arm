# rpi4-boot.nix - Minimal bootable Raspberry Pi 4 configuration
{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules/rpi-image.nix
  ];

  boot.initrd.availableKernelModules = [
    "sdhci_iproc"          # Pi 4 SD/MMC controller
    "usbhid" "hid_generic"
    "usbnet" "cdc_ether" "rndis_host"
  ];

  rpi = {
    enable = true;

    uboot.package = pkgs.ubootRaspberryPi4;
    deviceTree = "broadcom/bcm2711-rpi-4-b.dtb";

    console = {
      earlycon = "uart8250,mmio32,0xfe215040";  # Pi 4 mini-UART
      console = "tty1";
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = lib.mkDefault "25.11";

  console.enable = lib.mkDefault true;
}
