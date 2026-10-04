-- Go tools come from nix (nvim/default.nix), not mason.
local from_nix = { goimports = true, gofumpt = true, gomodifytags = true, impl = true, delve = true }

return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { gopls = { mason = false } } },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return not from_nix[tool]
      end, opts.ensure_installed or {})
    end,
  },
}
