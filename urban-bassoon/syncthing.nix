{ pkgs, ... }:
{
  services.syncthing = {
    enable = true;
    user = "lakin";
    dataDir = "/home/lakin";
    configDir = "/home/lakin/.config/syncthing";
    openDefaultPorts = true;
  };
}
