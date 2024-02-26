{ pkgs }: 

let
  # set the configurations here
  compileKernel = true;
  kernelVersion = "6.7.6";
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "e489ec0e1370d089b446d565aded7a698093d2b7c4122a18f21edb6ef93d37d3";
        };
        version = kernelVersion;
        modDirVersion = kernelVersion;
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages