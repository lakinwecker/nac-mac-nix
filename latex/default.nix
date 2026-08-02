{ pkgs, ... }:
{
  environment.systemPackages = [
    # texliveMedium == scheme-medium; texlive.combine is removed in 27.05.
    (pkgs.texliveMedium.withPackages (ps: with ps; [
      ebgaramond
      marginnote
      sectsty
      parskip
      ulem
      relsize
      setspace
    ]))
  ];

  fonts.packages = with pkgs; [
    google-fonts
  ];
}
