{ pkgs }: 

let
  # set the configurations here
  compileKernel = false;
  kernelVersion = "6.12.1";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "0193b1d86dd372ec891bae799f6da20deef16fc199f30080a4ea9de8cef0c619";
        };
        version = kernelVersion;
        modDirVersion = kernelVersion;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages