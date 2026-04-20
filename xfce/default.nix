{ pkgs, lib, username, xfceWallpaper ? null, xfceAvatar ? null, ... }:
{
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.displayManager.defaultSession = "xfce";
  services.xserver.displayManager.lightdm = {
    enable = true;
    extraConfig = ''
      [Seat:*]
      autologin-user=${username}
    '';
    greeters.gtk.extraConfig = lib.mkIf (xfceWallpaper != null) ''
      background=/etc/wallpaper.jpg
    '';
  };

  # Use NetworkManager instead of iwd/networkd for XFCE panel integration.
  # Priority 49 beats the mkForce (priority 50) in common/networking.nix.
  networking.networkmanager.enable = lib.mkOverride 49 true;
  networking.wireless.iwd.enable = lib.mkOverride 49 false;
  networking.useNetworkd = lib.mkOverride 49 false;
  systemd.network.enable = lib.mkOverride 49 false;

  environment.systemPackages = with pkgs; [
    xfce4-terminal
    xfce4-screenshooter
    xfce4-taskmanager
    networkmanagerapplet
    pavucontrol
    xclip
  ];

  environment.etc."wallpaper.jpg" = lib.mkIf (xfceWallpaper != null) {
    source = xfceWallpaper;
  };

  # User avatar — used by LightDM greeter and AccountsService
  system.activationScripts.xfceAvatar = lib.mkIf (xfceAvatar != null) {
    deps = [ "users" ];
    text = ''
      install -d -m 0755 /var/lib/AccountsService/icons
      install -m 0644 ${xfceAvatar} /var/lib/AccountsService/icons/${username}
      install -m 0644 ${xfceAvatar} /home/${username}/.face.icon
      chown ${username}:users /home/${username}/.face.icon
    '';
  };

  # Set wallpaper via XDG autostart — uses xrandr to discover monitor names
  # at runtime so it works on any hardware.
  environment.etc."xfce-set-wallpaper.sh" = lib.mkIf (xfceWallpaper != null) {
    text = ''
      #!/bin/sh
      sleep 2
      for monitor in $(xrandr --query | grep ' connected' | cut -d' ' -f1); do
        xfconf-query -c xfce4-desktop \
          -p "/backdrop/screen0/monitor''${monitor}/workspace0/last-image" \
          --create -t string -s "/etc/wallpaper.jpg"
        xfconf-query -c xfce4-desktop \
          -p "/backdrop/screen0/monitor''${monitor}/workspace0/image-style" \
          --create -t int -s 5
      done
    '';
    mode = "0755";
  };

  environment.etc."xdg/autostart/set-wallpaper.desktop" = lib.mkIf (xfceWallpaper != null) {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Set Wallpaper
      Exec=/etc/xfce-set-wallpaper.sh
      NoDisplay=true
      X-XFCE-Autostart-Override=true
    '';
  };
}
