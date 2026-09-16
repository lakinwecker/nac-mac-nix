{ pkgs, ... }:
{
  environment.systemPackages = [
    # texliveMedium == scheme-medium; texlive.combine is removed in 27.05.
    (pkgs.texliveMedium.withPackages (ps: with ps; [
      biber
      biblatex
      ebgaramond
      marginnote
      sectsty
      parskip
      ulem
      relsize
      setspace
      pdfrender
      contour
    ]))
  ];

  fonts.packages = with pkgs; [
    google-fonts
  ];
}
