-- NOTE: first use downloads libvscode_diff.so and loads it over FFI, with no
-- pure-Lua fallback. It resolves on NixOS because RPATH is $ORIGIN and the
-- installer puts a matching libgomp.so.1 beside it. `:CodeDiff install!` refetches.
-- NOTE: pinned. codediff fe7ab200 (v2.50.x, 2026-07-08) retyped session_config
-- `original_path`/`modified_path` strings as `original`/`modified` Path objects
-- and replaced `mode`/`explorer_data` with `panel`. Neogit master still sends the
-- old shape, so its `dd` crashes on nil `ref`. v2.49.2 is the last release that
-- matches. Unpin once NeogitOrg/neogit updates integrations/codediff.lua.
-- NOTE: tokyonight's Comment (#565f89) sits at 2.18:1 on codediff's insert
-- background, well under the 4.5:1 needed to read. #8a94c4 clears it on both
-- diff backgrounds. Scoped to a window-local namespace so normal editing keeps
-- the dimmer comments; the namespace is what reaches treesitter's @comment.
local comment_ns = vim.api.nvim_create_namespace("codediff_readable_comments")

local function readable_comments(tabpage)
  local hl = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  hl.fg = 0x8a94c4
  vim.api.nvim_set_hl(comment_ns, "Comment", hl)
  vim.api.nvim_set_hl(comment_ns, "@comment", hl)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    vim.api.nvim_win_set_hl_ns(win, comment_ns)
  end
end

return {
  "esmuellert/codediff.nvim",
  tag = "v2.49.2",
  cmd = "CodeDiff",
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeDiffOpen",
      callback = function(ev)
        local tabpage = ev.data and ev.data.tabpage
        if tabpage and vim.api.nvim_tabpage_is_valid(tabpage) then
          readable_comments(tabpage)
        end
      end,
    })
  end,
  opts = {
    diff = {
      ignore_trim_whitespace = true,
    },
    explorer = {
      position = "left",
      hidden = false,
      width = 40,
      height = 30,
      auto_refresh = true,
      indent_markers = true,
      initial_focus = "explorer",
      view_mode = "list",
      flatten_dirs = true,
      file_filter = {
        ignore = { ".git/**", ".jj/**" },
      },
      focus_on_select = false,
      auto_open_on_cursor = false,
      status_right_margin = 1,
      visible_groups = {
        staged = true,
        unstaged = true,
        conflicts = true,
      },
    },
  },
  keys = {
    { "<leader>gd", "<cmd>CodeDiff<cr>", desc = "CodeDiff" },
  },
}
