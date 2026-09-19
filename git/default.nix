{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    difftastic
  ];

  programs.git = {
    enable = true;
    config = {
      # `--no-ext-diff` restores classic output; lazygit already passes it.
      diff.external = "${pkgs.difftastic}/bin/difft";
      diff.tool = "difftastic";
      difftool.prompt = false;
      difftool.difftastic.cmd = ''${pkgs.difftastic}/bin/difft "$LOCAL" "$REMOTE"'';
      pager.difftool = true;
      alias.dft = "difftool";
    };
  };
}
