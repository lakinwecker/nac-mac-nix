{ lib, pkgs, username, lanMouseReceiveOnly ? false, ... }:
{
  # ── Networking (NetworkManager) ─────────────────────────────────────
  # NetworkManager is the single stack across every machine: the Wayland
  # bar (Wayle), the XFCE panel, and GNOME all read NM over D-Bus, and NM
  # manages both wifi (wpa_supplicant) and wired links. nmtui/nmcli are the
  # TUI/CLI front-ends.
  #
  # This replaced an iwd + systemd-networkd setup. The old iwd tuning —
  # mt7921e 2.4GHz band-biasing and DisablePeriodicScan (which stopped
  # periodic scans from deauthing the link and tearing down nebula while
  # idle) — did not carry over. If that hardware regresses, revisit the
  # NM/wpa_supplicant equivalents (connection.bgscan, band hints).
  networking.networkmanager.enable = true;

  # nebula owns the mesh tun; keep NM's hands off it.
  networking.networkmanager.unmanaged = [ "interface-name:nebula1" ];

  # ── DNS ────────────────────────────────────────────────────────────
  # Route NM's per-link DNS through systemd-resolved so the global
  # Domains=~. override still wins over whatever DHCP hands out.
  networking.networkmanager.dns = "systemd-resolved";
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" ];
  services.resolved = {
    enable = true;
    settings.Resolve.Domains = "~.";
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
      # `daemon` subcommand, not `--daemon` — 0.11 moved to subcommands and the
      # old flag now exits 2 (INVALIDARGUMENT).
      #
      # --config points at /etc rather than ~/.config on purpose. Hosts with
      # boot.initrd.systemd.enable run NixOS activation before /home is
      # mounted, so an activation script writing the config lands in the bare
      # mountpoint and is shadowed the moment /home mounts over it. /etc is
      # part of the system closure and always correct.
      # Flags go BEFORE the subcommand — usage is `lan-mouse [OPTIONS] [COMMAND]`.
      # `daemon --config ...` exits 2/INVALIDARGUMENT.
      #
      # lanMouseReceiveOnly adds `--capture-backend dummy`, which stops this
      # host ever opening an input-capture portal session. That matters because
      # xdg-desktop-portal-hyprland leaks an EIS fd per session and lan-mouse
      # opens one per barrier crossing; after ~36 the D-Bus session bus runs
      # out of in-flight fd references and xdg-desktop-portal segfaults, taking
      # every client on that bus down with it.
      #   https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/419
      #   fix: PR #421, unmerged, part 2 of 3
      # Measured on trunkie: with the dummy backend, zero sessions and zero fd
      # growth. Emulation is unaffected — it uses the wlroots virtual-input
      # protocols and never touches the portal — so the host can still receive
      # input, it just cannot initiate a crossing itself.
      ExecStart = "${pkgs.lan-mouse}/bin/lan-mouse --config /etc/lan-mouse/config.toml"
        + lib.optionalString lanMouseReceiveOnly " --capture-backend dummy"
        + " daemon";
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
    user = username;
    dataDir = "/home/${username}";
    configDir = "/home/${username}/.config/syncthing";
    openDefaultPorts = true;
  };
}
