# Vendored copy of nixpkgs' rose-pine-gtk-theme, which was removed because it
# depended on gtk-engine-murrine (dropped as an unmaintained GTK2 engine).
#
# The GTK2 engines were only ever needed for GTK2 apps: upstream's nixpkgs
# derivation carried gtk-engine-murrine in propagatedUserEnvPkgs and
# gnome-themes-extra/gtk_engines in buildInputs, but it is `dontBuild` and its
# installPhase copies nothing but gtk3/ and gtk4/ files. souris runs GNOME with
# GTK3/GTK4 apps, so dropping all three changes nothing we install.
#
# ./rose-pine-theme.nix overrides this to add the GNOME Shell themes.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "rose-pine-gtk-theme";
  version = "2.2.0";

  src = fetchFromGitHub {
    owner = "rose-pine";
    repo = "gtk";
    tag = "v${version}";
    hash = "sha256-vCWs+TOVURl18EdbJr5QAHfB+JX9lYJ3TPO6IklKeFE=";
  };

  # The upstream Makefile is for theme maintainers only.
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/themes/rose-pine{,-dawn,-moon}/gtk-4.0

    variants=("rose-pine" "rose-pine-dawn" "rose-pine-moon")
    for n in "''${variants[@]}"; do
      cp -r $src/gtk3/"''${n}"-gtk/* $out/share/themes/"''${n}"
      cp -r $src/gtk4/"''${n}".css $out/share/themes/"''${n}"/gtk-4.0/gtk.css
    done

    runHook postInstall
  '';

  meta = {
    description = "Rosé Pine theme for GTK";
    homepage = "https://github.com/rose-pine/gtk";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
