{ pkgs }: 

let
  # set the configurations here
  compileKernel = true;
  kernelVersion = "6.7.8";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "469ff46b98685df13b56c98417c64ba7a30f8a45baf34aa99f07935e1bf65c18";
        };
        version = kernelVersion;
        modDirVersion = kernelVersion;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages