-- <leader>e opens or focuses the explorer; <leader>b toggles it.
local function explorer()
  return Snacks.picker.get({ source = "explorer" })[1]
end

local function open()
  Snacks.explorer({ cwd = LazyVim.root() })
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>e",
        function()
          local p = explorer()
          if p then p:focus() else open() end
        end,
        desc = "Explorer (open/focus)",
      },
      {
        "<leader>b",
        function()
          local p = explorer()
          if p then p:close() else open() end
        end,
        desc = "Explorer (toggle)",
      },
    },
  },
}
