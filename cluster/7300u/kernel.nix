{ pkgs }: 

let
  # set the configurations here
  compileKernel = false;
  kernelVersion = "6.6.63";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "d1054ab4803413efe2850f50f1a84349c091631ec50a1cf9e891d1b1f9061835";
        };
        version = kernelVersion;
        modDirVersion = kernelVersion;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages