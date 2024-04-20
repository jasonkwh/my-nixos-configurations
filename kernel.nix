{ pkgs }: 

let
  # set the configurations here
  compileKernel = false;
  kernelVersion = "6.8.1";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "8d0c8936e3140a0fbdf511ad7a9f21121598f3656743898f47bb9052d37cff68";
        };
        version = kernelVersion;
        modDirVersion = kernelVersion;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages