# Pin MT7922 (mt7921e) WiFi firmware to the 20240220 linux-firmware tag: later
# blobs deauth the card every ~10-20 min when idle (openwrt/mt76#987).
{ ... }:
let
  tag  = "20240220";
  base = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/mediatek";
in
{
  nixpkgs.overlays = [
    (final: prev: {
      linux-firmware = prev.linux-firmware.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          echo "Pinning MT7922 firmware to linux-firmware tag ${tag} (mt76#987)"
          install -Dm444 ${prev.fetchurl {
            name = "WIFI_MT7922_patch_mcu_1_1_hdr.bin";
            url  = "${base}/WIFI_MT7922_patch_mcu_1_1_hdr.bin?h=${tag}";
            hash = "sha256-dxXE85KDvIWj0FjZzBxYejo+SQvTVN5Gx2ANoCJ0GMI=";
          }} $out/lib/firmware/mediatek/WIFI_MT7922_patch_mcu_1_1_hdr.bin
          install -Dm444 ${prev.fetchurl {
            name = "WIFI_RAM_CODE_MT7922_1.bin";
            url  = "${base}/WIFI_RAM_CODE_MT7922_1.bin?h=${tag}";
            hash = "sha256-fSNGZDjFQFhvEjt/Kj2TqdrSsklepgGEsRxD90e4QIg=";
          }} $out/lib/firmware/mediatek/WIFI_RAM_CODE_MT7922_1.bin
        '';
      });
    })
  ];
}
