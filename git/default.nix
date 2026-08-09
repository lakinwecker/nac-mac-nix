{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    difftastic
  ];

  # Writes /etc/gitconfig; ~/.gitconfig (user identity) still wins.
  programs.git = {
    enable = true;
    config = {
      # Structural diffs for diff/show/log -p. `--no-ext-diff` restores the
      # classic output; lazygit already passes it.
      diff.external = "${pkgs.difftastic}/bin/difft";
      diff.tool = "difftastic";
      difftool.prompt = false;
      difftool.difftastic.cmd = ''${pkgs.difftastic}/bin/difft "$LOCAL" "$REMOTE"'';
      pager.difftool = true;
      alias.dft = "difftool";
    };
  };
}
