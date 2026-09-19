-- LazyVim enables these by default (lazyvim/plugins/ui.lua); overriding here
-- keeps a LazyVim upgrade from turning them back on.
return {
  {
    "folke/snacks.nvim",
    opts = {
      scroll = { enabled = false },
      indent = { animate = { enabled = false } },
    },
  },
}
