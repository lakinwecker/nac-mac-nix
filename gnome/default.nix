{ pkgs, lib, username, ... }:
{
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  # GNOME requires NetworkManager.
  # Priority 49 beats the mkForce (priority 50) in common/networking.nix.
  networking.networkmanager.enable = lib.mkOverride 49 true;
  networking.wireless.iwd.enable = lib.mkOverride 49 false;
  networking.useNetworkd = lib.mkOverride 49 false;
  systemd.network.enable = lib.mkOverride 49 false;

  environment.systemPackages = with pkgs; [
    gimp
    thunderbird
    gnome-tweaks
    mpv     # video player (totem is excluded below)
    loupe   # GNOME image/photo viewer
  ];

  # Remove GNOME bloat
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
    totem
  ];
}
