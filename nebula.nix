{ lib, ... }:
{
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

  systemd.services."nebula@mesh".serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
  };

  networking.firewall.allowedUDPPorts = [ 4242 ];
}
