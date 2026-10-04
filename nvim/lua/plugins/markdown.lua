-- prettier comes from nix (nvim/default.nix); width/wrap live in each project's .prettierrc.
return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      markdown = { "prettier" },
    },
  },
}
