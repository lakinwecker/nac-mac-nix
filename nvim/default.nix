{ pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  environment.systemPackages = with pkgs; [
    # Core runtime deps expected by LazyVim
    git
    curl
    ripgrep
    fd
    lazygit
    nodejs_22
    python3

    # Formatters / linters
    stylua
    shfmt
    prettier

    # Tree-sitter CLI
    tree-sitter

    # Clipboard support (Wayland)
    wl-clipboard

    # Optional
    fzf
    delta
  ];

  environment.etc."nvim/init.lua".source = ./init.lua;
  environment.etc."nvim/.neoconf.json".source = ./.neoconf.json;
  environment.etc."nvim/stylua.toml".source = ./stylua.toml;
  environment.etc."nvim/lua/config/lazy.lua".source = ./lua/config/lazy.lua;
  environment.etc."nvim/lua/config/options.lua".source = ./lua/config/options.lua;
  environment.etc."nvim/lua/config/keymaps.lua".source = ./lua/config/keymaps.lua;
  environment.etc."nvim/lua/config/autocmds.lua".source = ./lua/config/autocmds.lua;
  environment.etc."nvim/lua/plugins/tokyonight.lua".source = ./lua/plugins/tokyonight.lua;
  environment.etc."nvim/lua/plugins/avante.lua".source = ./lua/plugins/avante.lua;
  environment.etc."nvim/lua/plugins/lsp.lua".source = ./lua/plugins/lsp.lua;
  environment.etc."nvim/lua/plugins/typescript.lua".source = ./lua/plugins/typescript.lua;
  environment.etc."nvim/lua/plugins/flash.lua".source = ./lua/plugins/flash.lua;
  environment.etc."nvim/lua/plugins/linter.lua".source = ./lua/plugins/linter.lua;
  environment.etc."nvim/lua/plugins/disabled.lua".source = ./lua/plugins/disabled.lua;
  environment.etc."nvim/lua/plugins/example.lua".source = ./lua/plugins/example.lua;

  system.activationScripts.nvimConfig = {
    deps = [ "users" ];
    text = ''
      NVIM_CONFIG="/home/lakin/.config/nvim"
      mkdir -p "$NVIM_CONFIG/lua/config"
      mkdir -p "$NVIM_CONFIG/lua/plugins"
      ln -sf /etc/nvim/init.lua "$NVIM_CONFIG/init.lua"
      ln -sf /etc/nvim/.neoconf.json "$NVIM_CONFIG/.neoconf.json"
      ln -sf /etc/nvim/stylua.toml "$NVIM_CONFIG/stylua.toml"
      ln -sf /etc/nvim/lua/config/lazy.lua "$NVIM_CONFIG/lua/config/lazy.lua"
      ln -sf /etc/nvim/lua/config/options.lua "$NVIM_CONFIG/lua/config/options.lua"
      ln -sf /etc/nvim/lua/config/keymaps.lua "$NVIM_CONFIG/lua/config/keymaps.lua"
      ln -sf /etc/nvim/lua/config/autocmds.lua "$NVIM_CONFIG/lua/config/autocmds.lua"
      ln -sf /etc/nvim/lua/plugins/tokyonight.lua "$NVIM_CONFIG/lua/plugins/tokyonight.lua"
      ln -sf /etc/nvim/lua/plugins/avante.lua "$NVIM_CONFIG/lua/plugins/avante.lua"
      ln -sf /etc/nvim/lua/plugins/lsp.lua "$NVIM_CONFIG/lua/plugins/lsp.lua"
      ln -sf /etc/nvim/lua/plugins/typescript.lua "$NVIM_CONFIG/lua/plugins/typescript.lua"
      ln -sf /etc/nvim/lua/plugins/flash.lua "$NVIM_CONFIG/lua/plugins/flash.lua"
      ln -sf /etc/nvim/lua/plugins/linter.lua "$NVIM_CONFIG/lua/plugins/linter.lua"
      ln -sf /etc/nvim/lua/plugins/disabled.lua "$NVIM_CONFIG/lua/plugins/disabled.lua"
      ln -sf /etc/nvim/lua/plugins/example.lua "$NVIM_CONFIG/lua/plugins/example.lua"
      chown -R lakin:users "$NVIM_CONFIG"
    '';
  };
}
