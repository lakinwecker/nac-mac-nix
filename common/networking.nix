{ lib, pkgs, ... }:
{
  # ── Wifi (iwd) ──────────────────────────────────────────────────────
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        EnableNetworkConfiguration = true;
        RoamThreshold = "-70";
        RoamThreshold5G = "-76";
      };
      Network.EnableIPv6 = true;
      Settings.AutoConnect = true;
      Rank = {
        BandModifier5Ghz = "2.0";
      };
    };
  };

  # ── Wired (systemd-networkd) ────────────────────────────────────────
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-ethernet" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
      MulticastDNS = true;
    };
  };

  # ── mDNS (Avahi) ───────────────────────────────────────────────────
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    denyInterfaces = [ "docker0" "br-+" "veth+" "nebula1" ];
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # ── Ad blocking (Steven Black hosts) ───────────────────────────────
  networking.stevenblack = {
    enable = true;
    block = [ "fakenews" "gambling" "porn" "social" ];
  };

  # ── Firewall ───────────────────────────────────────────────────────
  networking.firewall.allowedTCPPorts = [ 4343 ];        # lan-mouse
  networking.firewall.allowedUDPPorts = [ 4343 4242 ];   # lan-mouse + nebula

  # ── SSH ─────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ── Security ────────────────────────────────────────────────────────
  security.polkit.enable = true;

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  # ── lan-mouse KVM ──────────────────────────────────────────────────
  systemd.user.services.lan-mouse = {
    description = "lan-mouse KVM";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.lan-mouse}/bin/lan-mouse --daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # ── Nebula mesh VPN ────────────────────────────────────────────────
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

  # ── Syncthing ──────────────────────────────────────────────────────
  services.syncthing = {
    enable = true;
    user = "lakin";
    dataDir = "/home/lakin";
    configDir = "/home/lakin/.config/syncthing";
    openDefaultPorts = true;
  };
}
