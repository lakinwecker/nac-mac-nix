-- First use downloads libvscode_diff.so and loads it over FFI; `:CodeDiff install!` refetches.
-- neogit still writes the pre-3.0 SessionConfig shape, so `dd` dies on a nil
-- `ref`: NeogitOrg/neogit#2008. `panel_session_config` below translates at the
-- seam; delete it and its wrapper in `config` once neogit updates.
-- #8a94c4, not tokyonight's Comment (#565f89, only 2.18:1 on codediff's insert
-- background): this clears 4.5:1 on both diff backgrounds. Window-local
-- namespace so normal editing keeps the dimmer comments.
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

-- codediff can only focus the explorer or step with ]f/[f/]c/[c; these land
-- directly on a pane.
local PANE_KEYS = {
  { lhs = "<leader>1", side = "original", desc = "codediff: focus original pane" },
  { lhs = "<leader>2", side = "modified", desc = "codediff: focus modified pane" },
}

local function focus_pane(tabpage, side)
  local lifecycle = require("codediff.ui.lifecycle")
  local original_win, modified_win = lifecycle.get_windows(tabpage)
  local win = (side == "original") and original_win or modified_win
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

-- Bind on every session buffer at once (panes, explorer, merge result).
local function bind_pane_keys(tabpage)
  local lifecycle = require("codediff.ui.lifecycle")
  for _, key in ipairs(PANE_KEYS) do
    lifecycle.set_tab_keymap(tabpage, "n", key.lhs, function()
      focus_pane(tabpage, key.side)
    end, { desc = key.desc })
  end
end

-- codediff swaps pane buffers on every file selection, so buffer-local keymaps
-- must be re-bound whenever a buffer is displayed in a diff tab.
local function bind_pane_keys_for_buffer(tabpage, bufnr)
  local lifecycle = require("codediff.ui.lifecycle")
  for _, key in ipairs(PANE_KEYS) do
    lifecycle.set_buf_keymap(tabpage, bufnr, "n", key.lhs, function()
      focus_pane(tabpage, key.side)
    end, { desc = key.desc })
  end
end

-- Translate a pre-3.0 SessionConfig into the panel/Path shape; current-shape
-- input passes through untouched.
local function panel_session_config(session_config)
  if type(session_config) ~= "table" or session_config.panel ~= nil or session_config.mode == nil then
    return session_config
  end

  local path = require("codediff.core.path")
  local translated = vim.tbl_extend("force", {}, session_config)
  translated.mode = nil
  translated.explorer_data = nil
  translated.history_data = nil
  translated.original_path = nil
  translated.modified_path = nil

  if session_config.mode == "explorer" then
    translated.panel = { name = "explorer", data = session_config.explorer_data or {} }
  elseif session_config.mode == "history" then
    translated.panel = { name = "history", data = session_config.history_data or {} }
  end

  -- Explorer mode passes "" for both sides; make_ref turns that into the empty
  -- Path that is_panel_placeholder looks for.
  translated.original = path.make_ref(session_config.original_path or "", session_config.git_root)
  translated.modified = path.make_ref(session_config.modified_path or "", session_config.git_root)

  return translated
end

return {
  "esmuellert/codediff.nvim",
  tag = "v3.1.3",
  cmd = "CodeDiff",
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeDiffOpen",
      callback = function(ev)
        local tabpage = ev.data and ev.data.tabpage
        if tabpage and vim.api.nvim_tabpage_is_valid(tabpage) then
          readable_comments(tabpage)
          bind_pane_keys(tabpage)
        end
      end,
    })

    vim.api.nvim_create_autocmd("BufWinEnter", {
      callback = function(ev)
        -- Fires for every buffer in every window; keep this to one table lookup.
        if not package.loaded["codediff.ui.lifecycle"] then
          return
        end
        local tabpage = vim.api.nvim_get_current_tabpage()
        if require("codediff.ui.lifecycle").get_session(tabpage) then
          bind_pane_keys_for_buffer(tabpage, ev.buf)
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
      line_stats = {
        enabled = true,
        -- Counting untracked files means reading each one; they show no +N without it.
        count_untracked = false,
      },
      visible_groups = {
        staged = true,
        unstaged = true,
        conflicts = true,
      },
    },
  },
  config = function(_, opts)
    require("codediff").setup(opts)

    local view = require("codediff.ui.view")
    if not view.__nac_neogit_compat then
      local create = view.create
      view.create = function(session_config, filetype, on_ready)
        return create(panel_session_config(session_config), filetype, on_ready)
      end
      view.__nac_neogit_compat = true
    end
  end,
  keys = {
    { "<leader>gd", "<cmd>CodeDiff<cr>", desc = "CodeDiff" },
  },
}
