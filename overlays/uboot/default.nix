final: prev: {
  uboot-rk3582-generic = prev.buildUBoot {
    pname = "uboot-rk3582-generic";
    defconfig = "generic-rk3588_defconfig";
    
    # RK3582 support (formerly patches/000{1,2}) is upstream as of U-Boot 2026.07.

    # buildUBoot uses __structuredAttrs, so these must go through env to reach make
    env = {
      BL31 = "${prev.armTrustedFirmwareRK3588}/bl31.elf";
      ROCKCHIP_TPL = prev.rkbin.TPL_RK3588;
    };
    
    filesToInstall = [
      "u-boot.itb"
      "idbloader.img"
      "u-boot-rockchip.bin"
    ];
    
    extraMeta = {
      description = "Patched U-Boot for generic RK3582/RK3588 boards";
    };
  };

  ubootRock5ModelA = prev.buildUBoot {
    defconfig = "rock5a-rk3588s_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    env = {
      BL31 = "${prev.armTrustedFirmwareRK3588}/bl31.elf";
      ROCKCHIP_TPL = prev.rkbin.TPL_RK3588;
    };
    filesToInstall = [
      "u-boot.itb"
      "idbloader.img"
      "u-boot-rockchip.bin"
    ];
  };

  ubootOrangePi5Ultra = prev.buildUBoot {
    version = "v2025.10-rc5";
    src = prev.fetchFromGitHub {
      owner = "u-boot";
      repo = "u-boot";
      rev = "v2025.10-rc5";
      hash = "sha256-EJOS0wRIRBexyX2d0GyIWpGIpB3+fUeXiHZvhEfrhYA=";
    };
    defconfig = "orangepi-5-ultra-rk3588_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    env = {
      BL31 = "${prev.armTrustedFirmwareRK3588}/bl31.elf";
      ROCKCHIP_TPL = prev.rkbin.TPL_RK3588;
    };
    filesToInstall = [
      "u-boot.itb"
      "idbloader.img"
      "u-boot-rockchip.bin"
      "u-boot-rockchip-spi.bin"
    ];
  };

  ubootNanopiR6S = prev.buildUBoot {
    defconfig = "nanopi-r6s-rk3588s_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    env = {
      BL31 = "${prev.armTrustedFirmwareRK3588}/bl31.elf";
      ROCKCHIP_TPL = prev.rkbin.TPL_RK3588;
    };
    filesToInstall = [
      "u-boot.itb"
      "idbloader.img"
      "u-boot-rockchip.bin"
    ];
  };

}
