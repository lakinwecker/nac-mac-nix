# rose-pine-gtk-theme, extended with GNOME Shell (top bar) themes that the
# nixpkgs package doesn't install:
#
#   rose-pine-moon  — the upstream Moon (dark) shell theme, copied verbatim.
#   rose-pine-dawn  — a light shell theme we derive from Moon, because upstream
#                     ships no light one. We remap the Moon palette to Dawn by
#                     role across the CSS + SVG assets.
#
# The remap is driven by the `palette` table below rather than a wall of sed
# flags: each role names its Dawn target and the Moon-side source values (in
# both #hex and decimal "r, g, b" forms, as they appear in the theme). The
# rewrite is two-pass via per-role placeholder tokens so replacements never
# chain — e.g. Moon base #232136 → Dawn base #faf4ed must not then be caught
# by Moon's own #faf4ed → text rule.
{ lib, rose-pine-gtk-theme }:

let
  # role -> { hex; rgb?; fromHex?; fromRgb?; }
  #   hex/rgb  = Dawn target value for this role
  #   fromHex  = Moon #hex source values that map to it
  #   fromRgb  = Moon "r, g, b" source values that map to it
  palette = {
    base    = { hex = "#faf4ed"; rgb = "250, 244, 237"; fromHex = [ "#191724" "#232136" "#151515" ]; fromRgb = [ "35, 33, 54" ]; };
    surface = { hex = "#fffaf3";                        fromHex = [ "#2a273f" ]; };
    overlay = { hex = "#f2e9e1"; rgb = "242, 233, 225"; fromHex = [ "#242424" "#272727" ]; fromRgb = [ "57, 53, 82" "33, 33, 33" ]; };
    hlLow   = { hex = "#f4ede8"; rgb = "244, 237, 232"; fromHex = [ "#2a283e" ]; fromRgb = [ "40, 38, 52" ]; };
    hlMed   = { hex = "#dfdad9"; rgb = "223, 218, 217"; fromHex = [ "#313131" "#333333" "#353535" "#444444" "#455a64" ]; fromRgb = [ "44, 44, 44" ]; };
    hlHigh  = { hex = "#cecacd";                        fromHex = [ "#404040" "#4b4b4b" "#525252" "#535353" ]; };
    muted   = { hex = "#9893a5";                        fromHex = [ "#575757" "#616161" "#666666" ]; };
    subtle  = { hex = "#797593";                        fromHex = [ "#ededed" "#e0e0e0" "#c7c7c7" "#f5f5f5" ]; };
    text    = { hex = "#575279"; rgb = "87, 82, 121";   fromHex = [ "#e0def4" "#ffffff" "#faf4ed" ]; fromRgb = [ "224, 222, 244" "250, 244, 237" "250, 243, 237" ]; };
    love    = { hex = "#b4637a";                        fromHex = [ "#eb6f92" "#f28b82" ]; };
    rose    = { hex = "#d7827e";                        fromHex = [ "#ebbcba" "#ea9a97" ]; };
    gold    = { hex = "#ea9d34";                        fromHex = [ "#fdd633" ]; };
    pine    = { hex = "#286983"; rgb = "40, 105, 131";  fromHex = [ "#2196f3" "#0c7cd5" ]; fromRgb = [ "33, 150, 243" ]; };
    foam    = { hex = "#56949f";                        fromHex = [ "#56949f" "#51adf6" ]; };
  };

  hexTok = role: "@${lib.toUpper role}@";
  rgbTok = role: "@R${lib.toUpper role}@";
  # Match Moon "r, g, b" with flexible inter-channel spacing.
  rgbPat = v: lib.replaceStrings [ ", " ] [ ", *" ] v;

  sed = expr: "-e '${expr}'";
  # Pass 1: every source value -> its role token.
  toTokens = lib.concatLists (lib.mapAttrsToList (role: v:
    map (h: sed "s/${h}/${hexTok role}/gI") (v.fromHex or [])
    ++ map (r: sed "s/${rgbPat r}/${rgbTok role}/g") (v.fromRgb or [])
  ) palette);
  # Pass 2: each role token -> its Dawn value.
  toDawn = lib.concatLists (lib.mapAttrsToList (role: v:
    [ (sed "s/${hexTok role}/${v.hex}/g") ]
    ++ lib.optional (v ? rgb) (sed "s/${rgbTok role}/${v.rgb}/g")
  ) palette);

  sedArgs = lib.concatStringsSep " " (toTokens ++ toDawn);
in
rose-pine-gtk-theme.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    # Moon (dark) shell theme — upstream, as-is.
    cp -r $src/gnome_shell/moon/gnome-shell $out/share/themes/rose-pine-moon/gnome-shell

    # Dawn (light) shell theme — Moon recolored to the Dawn palette.
    cp -r $src/gnome_shell/moon/gnome-shell $out/share/themes/rose-pine-dawn/gnome-shell
    chmod -R u+w $out/share/themes/rose-pine-dawn/gnome-shell
    find $out/share/themes/rose-pine-dawn/gnome-shell -type f \( -name '*.css' -o -name '*.svg' \) \
      -exec sed -i ${sedArgs} {} +
  '';
})
