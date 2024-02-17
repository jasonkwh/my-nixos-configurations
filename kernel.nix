{ pkgs }: 

let
  # set the configurations here
  compileKernel = true;
  kernelVersion = "6.7.5";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "29f6464061b8179cbb77fc5591e06a2199324e018c9ed730ca3e6dfb145539ff";
        };
        version = kernelVersion;
        modDirVersion = kernel;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages