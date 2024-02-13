{ pkgs }: 

let
  compileKernel = true;
  
  kernelPackages = if compileKernel then
    pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "f68d9f5ffc0a24f850699b86c8aea8b8687de7384158d5ed3bede37de098d60c";
        };
        version = "6.7.4";
        modDirVersion = "6.7.4";
      };
    })
  else
    pkgs.linuxPackages_latest;
in
  kernelPackages