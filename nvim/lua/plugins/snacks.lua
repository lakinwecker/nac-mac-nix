-- LazyVim enables these by default (lazyvim/plugins/ui.lua); overriding here
-- keeps a LazyVim upgrade from turning them back on.
-- The global kill switch is vim.g.snacks_animate in lua/config/options.lua --
-- these opts only cover two modules, so both layers are wanted.
return {
  {
    "folke/snacks.nvim",
    opts = {
      scroll = { enabled = false },
      indent = { animate = { enabled = false } },
    },
  },
}
