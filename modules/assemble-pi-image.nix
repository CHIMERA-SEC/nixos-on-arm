{ pkgs, lib,
  # Pre-built filesystem images
  nixosBootImageFile,
  nixosRootfsImageFile,

  # Image layout config
  imageName ? "nixos-rpi-image",
  imagePaddingMB ? 100,
  bootOffsetMB ? 1,
}:

let
  alignmentUnitBytes = 1 * 1024 * 1024;
  bytesToSectors = bytes: builtins.floor (bytes / 512);

  bootPartitionStartBytes = bootOffsetMB * 1024 * 1024;
  bootPartitionStartSectors = bytesToSectors bootPartitionStartBytes;

  linuxFsTypeGuid = "0FC63DAF-8483-4772-8E79-3D69D8477DE4";
  efiSysTypeGuid = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B";

in pkgs.stdenv.mkDerivation {
  pname = imageName;
  version = "assembled";

  src = null;
  dontUnpack = true;

  inherit nixosBootImageFile nixosRootfsImageFile;
  inherit imagePaddingMB;

  nativeBuildInputs = [
    pkgs.coreutils
    pkgs.util-linux
  ];

  buildPhase = ''
    set -xe

    local boot_part_start_sectors=${toString bootPartitionStartSectors}
    local linux_fs_type_guid="${linuxFsTypeGuid}"
    local efi_sys_type_guid="${efiSysTypeGuid}"
    local alignment_unit_bytes=${toString alignmentUnitBytes}
    local img_name="${imageName}-sdcard.img"

    local boot_img_size_bytes=$(stat -c %s "$nixosBootImageFile")
    local rootfs_img_size_bytes=$(stat -c %s "$nixosRootfsImageFile")
    local boot_img_min_sectors=$(( (boot_img_size_bytes + 511) / 512 ))
    local rootfs_img_min_sectors=$(( (rootfs_img_size_bytes + 511) / 512 ))

    local rootfs_part_start_sectors=$(( boot_part_start_sectors + boot_img_min_sectors ))
    local img_min_end_bytes=$(( rootfs_part_start_sectors * 512 + rootfs_img_size_bytes ))

    local val_to_align=$(( img_min_end_bytes + (imagePaddingMB * 1024 * 1024) ))
    local img_total_size_bytes=$(( (val_to_align + alignment_unit_bytes - 1) / alignment_unit_bytes * alignment_unit_bytes ))

    truncate -s "''${img_total_size_bytes}" "''${img_name}"

    sfdisk "''${img_name}" << EOF
label: gpt
unit: sectors
first-lba: 34
name="NIXOS_BOOT", start=$boot_part_start_sectors, size=$boot_img_min_sectors, type="$efi_sys_type_guid"
name="NIXOS_ROOT", start=$rootfs_part_start_sectors, type="$linux_fs_type_guid"
EOF
    dd if="$nixosBootImageFile" of="''${img_name}" seek="$boot_part_start_sectors" conv=notrunc,fsync bs=512 status=progress
    dd if="$nixosRootfsImageFile" of="''${img_name}" seek="$rootfs_part_start_sectors" conv=notrunc,fsync bs=512 status=progress
    echo "--- Pi SD image created: ''${img_name} ---"
  '';

  installPhase = ''
    mkdir -p $out
    mv "${imageName}-sdcard.img" $out/
  '';

  dontStrip = true;
  dontFixup = true;
}
