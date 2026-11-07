# Fleet inventory. Hardware lives in cluster/<name>/, not /etc/nixos.
# maxBuildJobs = min(cores, RAM_GB/4); Pi is 1 (hub services).
# hostPublicKey: on-board ssh_host_ed25519_key.pub — never ssh-keyscan.
{ nixos-hardware }:
{
  "jasonkwh-7300u" = {
    name = "7300u";
    hostSystem = "x86_64-linux";
    isLaptop = true;
    isBuilder = true;
    buildSpeed = 2;
    maxBuildJobs = 2;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKk5ItDGM2FVXZhn7c2B7u96cgximMG2fmlR6B+7nef1";
    syncthingId = "U5DJ45M-J37KSC4-6D5Y2KZ-ARKDIQ7-SAPGPD3-IVIUI6M-3NOIOGZ-I2X3QQV";
  };
  "jasonkwh-7520u" = {
    name = "7520u";
    hostSystem = "x86_64-linux";
    isLaptop = true;
    isBuilder = true;
    buildSpeed = 3;
    maxBuildJobs = 4;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIODXodoJLkTtxwWGkqXIWW2dC0BXN/uHgb7eABbczTEZ";
    syncthingId = "WGJTJ54-F66PGU2-RRUYEYV-DBUDMT7-YNCBJYI-6YKCJID-CJRD5GT-DUI6CQ5";
  };
  "jasonkwh-2450m" = {
    name = "2450m";
    hostSystem = "x86_64-linux";
    isLaptop = true;
    isBuilder = true;
    buildSpeed = 1;
    maxBuildJobs = 2;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+KOrVNYK6dBw+Ucv53poZ2Ptszaav5ZpFA+j/5+FKP";
    syncthingId = "WGQMBDR-UDX7MWW-JMDKKSQ-PRSIE6H-WJXKGGU-PMPCZKA-JV6VJL6-C6YBSAN";
  };
  "jasonkwh-bcm2711" = {
    name = "bcm2711";
    hostSystem = "aarch64-linux";
    isHeadless = true;
    isFleetHub = true;
    isBuilder = true;
    isLadderServer = true;
    buildSpeed = 1;
    maxBuildJobs = 1;
    extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMliakPvWur4Rh8cPKw83mEFGwfS/2OlsfO5g9p+BztM";
    syncthingId = "3HVJKXT-JBAOZME-7IO7IXE-ZVA3RPU-NVZ37PL-G26C3V7-JFAETLE-ZOFKBAB";
  };
  "jasonkwh-3210m" = {
    name = "3210m";
    hostSystem = "x86_64-linux";
    isLaptop = true;
    isBuilder = true;
    buildSpeed = 1;
    maxBuildJobs = 2;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsR36gqTe9gKZ6y7STXvHaLbN/lDIJH9xD3c4akH4cN";
    syncthingId = "WOXKEDN-PWOAESC-GEULKND-C66M4IV-FPQTUWW-TL6554M-H2BSD2L-P2AF3QX";
  };
  "jasonkwh-1650v2" = {
    name = "1650v2";
    hostSystem = "x86_64-linux";
    isLaptop = false;
  };
  "jasonkwh-deck" = {
    name = "deck";
    hostSystem = "x86_64-linux";
    isSteamMachine = true;
    username = "deck";
    homeDirectory = "/home/deck";
  };
}
