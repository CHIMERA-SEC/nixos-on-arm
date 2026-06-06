{ config, lib, pkgs, modulesPath, hostPkgs ? pkgs.buildPackages, ... }:
with lib;
let
  cfg = config.rpi;
  ubootPackage = cfg.uboot.package;
  firmwarePackage = cfg.firmware.package;
  assemblerPkgs = hostPkgs;

  dtbSource = "${config.boot.kernelPackages.kernel}/dtbs";
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
  ];

  ###### Interface ######
  options = {
    rpi = {
      enable = mkEnableOption "Raspberry Pi support";
      uboot.package = mkOption {
        type = types.package;
        description = "U-Boot package providing u-boot.bin (chainloaded by Pi firmware).";
      };
      firmware.package = mkOption {
        type = types.package;
        default = pkgs.raspberrypifw;
        description = "Raspberry Pi GPU/VPU firmware (bootcode.bin, start*.elf, fixup*.dat).";
      };
      image = {
        name = mkOption { type = types.str; default = "nixos-rpi"; };
        imagePaddingMB = mkOption { type = types.int; default = 100; };
        bootPartitionSize = mkOption { type = types.str; default = "512M"; };
        bootOffsetMB = mkOption { type = types.int; default = 1; };
      };
      deviceTree = mkOption {
        type = types.str;
        description = "DTB filename relative to kernel dtbs dir (e.g. broadcom/bcm2711-rpi-4-b.dtb).";
      };
      configTxt = mkOption {
        type = types.lines;
        default = ''
          arm_64bit=1
          enable_uart=1
          kernel=u-boot.bin
        '';
        description = "Contents of config.txt loaded by the Pi GPU firmware.";
      };
      console = {
        earlycon = mkOption { type = types.nullOr types.str; default = null; };
        console = mkOption { type = types.nullOr types.str; default = null; };
      };
    };
  };

  ###### Implementation ######
  config = mkIf cfg.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.grub.enable = false;

    hardware.firmware = with pkgs; [ linux-firmware ];
    hardware.deviceTree = {
      enable = true;
      name = cfg.deviceTree;
    };

    system.build.nixosBootPartitionImage = assemblerPkgs.callPackage ./make-fat-fs.nix {
      volumeLabel = "NIXOS_BOOT";
      size = cfg.image.bootPartitionSize;
      populateImageCommands = ''
        mkdir -p ./files/EFI/BOOT
        mkdir -p ./files/EFI/systemd
        mkdir -p ./files/EFI/nixos
        mkdir -p ./files/loader/entries
        mkdir -p ./files/overlays

        # Stage 0: Pi GPU firmware (loaded by the SoC bootrom)
        cp ${firmwarePackage}/share/raspberrypi/boot/bootcode.bin ./files/bootcode.bin
        cp ${firmwarePackage}/share/raspberrypi/boot/start4.elf   ./files/start4.elf
        cp ${firmwarePackage}/share/raspberrypi/boot/fixup4.dat   ./files/fixup4.dat

        # Stage 1: U-Boot chainloaded as "kernel" by Pi firmware
        cp ${ubootPackage}/u-boot.bin ./files/u-boot.bin

        # Pi firmware config — points firmware at u-boot.bin
        cat > ./files/config.txt <<EOF
        ${cfg.configTxt}
        EOF

        # Devicetree (Pi firmware loads and patches it, then passes to U-Boot)
        cp ${dtbSource}/${cfg.deviceTree} ./files/$(basename ${cfg.deviceTree})

        # Stage 2: systemd-boot + UKI (loaded by U-Boot's EFI stub)
        cp ${pkgs.systemd}/lib/systemd/boot/efi/systemd-bootaa64.efi ./files/EFI/BOOT/BOOTAA64.EFI
        cp ${pkgs.systemd}/lib/systemd/boot/efi/systemd-bootaa64.efi ./files/EFI/systemd/systemd-bootaa64.efi
        cp ${config.system.build.uki}/${config.system.boot.loader.ukiFile} ./files/EFI/nixos/nixos.efi

        cat > ./files/loader/loader.conf <<EOF
        default nixos
        timeout 3
        console-mode max
        editor no
        EOF

        cat > ./files/loader/entries/nixos.conf <<EOF
        title   NixOS
        efi     /EFI/nixos/nixos.efi
        EOF
      '';
      storePaths = [ ];
    };

    system.build.nixosRootfsPartitionImage = assemblerPkgs.callPackage "${pkgs.path}/nixos/lib/make-ext4-fs.nix" {
      storePaths = [ config.system.build.toplevel ];
      volumeLabel = "NIXOS_ROOT";
      compressImage = false;
    };

    system.build.rpiImages = assemblerPkgs.callPackage ./assemble-pi-image.nix {
      nixosBootImageFile = config.system.build.nixosBootPartitionImage;
      nixosRootfsImageFile = config.system.build.nixosRootfsPartitionImage;
      imageName = cfg.image.name;
      imagePaddingMB = cfg.image.imagePaddingMB;
      bootOffsetMB = cfg.image.bootOffsetMB;
    };

    system.build.image = config.system.build.rpiImages;

    fileSystems = {
      "/" = { device = "/dev/disk/by-label/NIXOS_ROOT"; fsType = "ext4"; };
      "/boot" = { device = "/dev/disk/by-label/NIXOS_BOOT"; fsType = "vfat"; };
    };

    systemd.services.expand-root-fs = {
      description = "Expand Root Partition to Fill Disk";
      after = [ "systemd-remount-fs.service" ];
      wants = [ "systemd-remount-fs.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "!/etc/nixos-partition-resized";
      script = ''
        set -euo pipefail
        set -x
        rootPart="/dev/disk/by-label/NIXOS_ROOT"
        for i in $(seq 10); do
          [ -b "$rootPart" ] && break
          echo "Waiting for $rootPart..."
          sleep 1
        done
        if ! [ -b "$rootPart" ]; then
          echo "Device $rootPart never appeared!"
          exit 1
        fi
        rootDev=$(${pkgs.coreutils}/bin/readlink -f "$rootPart")
        partNum=$(echo "$rootDev" | ${pkgs.gnugrep}/bin/grep -o '[0-9]*$')
        bootDevice=$(echo "$rootDev" | ${pkgs.gnused}/bin/sed 's/p\?[0-9]*$//')
        echo "Root device: $rootDev"
        echo "Boot device: $bootDevice"
        echo "Partition number: $partNum"
        ${pkgs.cloud-utils}/bin/growpart "$bootDevice" "$partNum"
        ${pkgs.e2fsprogs}/bin/resize2fs "$rootDev"
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStartPost = "${pkgs.coreutils}/bin/touch /etc/nixos-partition-resized";
        Path = with pkgs; [ coreutils util-linux parted e2fsprogs gawk cloud-utils gnugrep gnused ];
      };
    };

    boot.postBootCommands = ''
      if [ -f /nix-path-registration ]; then
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
        rm -f /nix-path-registration
      fi
    '';

    environment.systemPackages = with pkgs; [
      iproute2
      cloud-utils
    ];
  };
}
