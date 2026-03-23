{ lib, ... }:
{
  services.nebula.networks.mesh = {
    enable = true;
    ca = "/etc/nebula/ca.crt";
    cert = "/etc/nebula/host.crt";
    key = "/etc/nebula/host.key";
    isLighthouse = false;
    lighthouses = []; # Fill in lighthouse IPs
    staticHostMap = {}; # Fill in lighthouse host:port mappings
    settings = {
      punchy = {
        punch = true;
        respond = true;
      };
      firewall = {
        outbound = [
          { port = "any"; proto = "any"; host = "any"; }
        ];
        inbound = [
          { port = "any"; proto = "icmp"; host = "any"; }
          { port = "22"; proto = "tcp"; host = "any"; }
        ];
      };
    };
  };

  networking.firewall.allowedUDPPorts = [ 4242 ];
}
