{ pkgs }: 

let
  # set the configurations here
  compileKernel = true;
  kernelVersion = "6.7.7";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "256b8b44570ddbe266eb3ad0c2cba2616f1609b4a3de5014a3da5512907b14d9";
        };
        version = kernelVersion;
        modDirVersion = kernelVersion;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages