{ pkgs }: 

let
  # set the configurations here
  compileKernel = false;
  kernelVersion = "6.9.2";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "d46c5bdf2c5961cc2a4dedefe0434d456865e95e4a7cd9f93fff054f9090e5f9";
        };
        version = kernelVersion;
        modDirVersion = kernelVersion;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages