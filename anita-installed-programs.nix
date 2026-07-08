# ════════════════════════════════════════════════════════════════════════
#  Anita's programs — this is YOUR file. Add or remove apps here.
# ════════════════════════════════════════════════════════════════════════
#
# ── TO ADD A PROGRAM ────────────────────────────────────────────────────
#   1. Find its name at   https://search.nixos.org/packages
#   2. Add the name on its own line in the list below (no commas, no quotes).
#   3. Save this file.
#   4. Open a terminal and run:   update-system
#
# ── TO REMOVE A PROGRAM ─────────────────────────────────────────────────
#   Delete its line (or put a  #  in front of it to disable it),
#   save, and run   update-system   again.
#
# ── EXAMPLE ─────────────────────────────────────────────────────────────
#   To add the VLC media player and the Signal messenger, the list would be:
#
#       vlc
#       signal-desktop
#
# Nothing can really break: if you mistype a name, update-system will tell
# you and change nothing. You can also pick the previous working version
# from the menu when the laptop starts up.
# ════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # ── Add your programs below this line ──────────────────────────────

  ];
}
