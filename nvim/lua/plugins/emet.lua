-- emet.nvim registers the filetype, the parser and emet_lsp; emet-lsp itself
-- comes from golem-tools (nvim/default.nix). A dependency so the parser is
-- registered before ensure_installed runs.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "dull-ca/emet.nvim" },
    opts = { ensure_installed = { "emet" } },
  },
}
