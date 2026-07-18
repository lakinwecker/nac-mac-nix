# System / disk / recovery tools, installed on every machine.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    file
    rsync
    ddrescue        # GNU ddrescue (a.k.a. "gddrescue" on Debian)
    cryptsetup
    lvm2
    e2fsprogs
    xxd
    smartmontools
  ];
}
