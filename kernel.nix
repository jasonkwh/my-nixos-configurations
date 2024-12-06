{ pkgs }: 

let
  # set the configurations here
  compileKernel = false;
  kernelVersion = "6.12.3";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "c89809cc777d50f1ea484a118630281a26383707a0e752c96fd834f6e765deae";
        };
        version = kernelVersion;
        modDirVersion = kernelVersion;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages