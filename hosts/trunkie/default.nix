# Threadripper desktop — hostname "trunkie"
{ pkgs, ... }:
{
  hardware.amdgpu.initrd.enable = true;
  environment.systemPackages = with pkgs; [ lm_sensors ];
}
