# Pin the MediaTek MT7922 (mt7921e) WiFi firmware to the Feb-2024 build.
#
# linux-firmware releases after Feb 2024 regressed the MT7922 firmware: the
# card spontaneously deauthenticates (kernel: "by local choice", reason 3,
# from_ap:false) every ~10-20 min *when the link is idle*, which tears down
# the nebula tunnel (gratch unreachable until a keypress). Power-save is off,
# ASPM off didn't help — it's the firmware blob itself.
#
# Upstream report: https://github.com/openwrt/mt76/issues/987
# Reverting the two firmware files to the 20240220 linux-firmware tag
# (firmware version 20240219103337, last-known-stable) fixes it.
#
# We override the base linux-firmware; NixOS re-compresses it to zstd.
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
