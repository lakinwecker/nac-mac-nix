{ lib, pkgs, username, lanMouseCaptureBackend ? null, ... }:
{
  networking.networkmanager.enable = true;

  # nebula owns the mesh tun; keep NM's hands off it.
  networking.networkmanager.unmanaged = [ "interface-name:nebula1" ];

  # Route NM's per-link DNS through resolved so Domains=~. beats DHCP.
  networking.networkmanager.dns = "systemd-resolved";
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" ];
  services.resolved = {
    enable = true;
    settings.Resolve.Domains = "~.";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    denyInterfaces = [ "docker0" "br-+" "veth+" "nebula1" ];
    publish = {
      enable = true;
      addresses = true;
    };
  };

  networking.stevenblack = {
    enable = true;
    block = [ "fakenews" "gambling" "porn" "social" ];
  };

  networking.firewall.allowedTCPPorts = [ 4343 ];        # lan-mouse
  networking.firewall.allowedUDPPorts = [ 4343 4242 ];   # lan-mouse + nebula

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  security.polkit.enable = true;

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  systemd.user.services.lan-mouse = {
    description = "lan-mouse KVM";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      # Flags go BEFORE the `daemon` subcommand; otherwise exits 2.
      # --config in /etc, not ~/.config: activation can run before /home mounts.
      # capture-backend "dummy" avoids the portal EIS fd leak that segfaults
      # xdg-desktop-portal (hyprwm/xdg-desktop-portal-hyprland#419); the cost is
      # this host can't initiate a crossing. Don't use "layer-shell" — stuck keys.
      ExecStart = "${pkgs.lan-mouse}/bin/lan-mouse --config /etc/lan-mouse/config.toml"
        + lib.optionalString (lanMouseCaptureBackend != null) " --capture-backend ${lanMouseCaptureBackend}"
        + " daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  services.nebula.networks.mesh = {
    enable = true;
    ca = "/etc/nebula/ca.crt";
    cert = "/etc/nebula/host.crt";
    key = "/etc/nebula/host.key";
    isLighthouse = false;
    lighthouses = [ "172.16.100.1" ];
    staticHostMap = {
      "172.16.100.1" = [ "lighthouse.lakin.ca:4242" ];
    };
    settings = {
      listen = {
        host = "0.0.0.0";
        port = 4242;
      };
      relay = {
        am_relay = false;
        use_relays = true;
        relays = [ "172.16.100.1" ];
      };
      tun = {
        dev = "nebula1";
        mtu = 1300;
      };
      punchy = {
        punch = true;
        respond = true;
      };
      firewall = {
        outbound = [
          { port = "any"; proto = "any"; host = "any"; }
        ];
        inbound = [
          { port = "any"; proto = "any"; host = "any"; }
        ];
      };
    };
  };

  systemd.services."nebula@mesh" = {
    unitConfig.ConditionPathExists = [
      "/etc/nebula/ca.crt"
      "/etc/nebula/host.crt"
      "/etc/nebula/host.key"
    ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
    };
  };

  services.syncthing = {
    enable = true;
    user = username;
    dataDir = "/home/${username}";
    configDir = "/home/${username}/.config/syncthing";
    openDefaultPorts = true;
  };
}
