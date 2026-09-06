-- NOTE: first use downloads libvscode_diff.so and loads it over FFI, with no
-- pure-Lua fallback. It resolves on NixOS because RPATH is $ORIGIN and the
-- installer puts a matching libgomp.so.1 beside it. `:CodeDiff install!` refetches.
-- NOTE: neogit's integrations/codediff.lua still writes the pre-3.0 SessionConfig
-- shape (`mode` + `explorer_data` + `original_path`/`modified_path` strings).
-- codediff dropped `mode` for a `panel` descriptor in 48576d2 and the path
-- strings for `Path` objects in fe7ab20, so neogit's `dd` dies on a nil `ref` in
-- view/helpers.lua. Tracked as NeogitOrg/neogit#2008 — open, no PR. Until it
-- lands, `panel_session_config` below translates the old shape at the seam.
-- Delete the shim (and its wrapper in `config`) once neogit updates.
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

-- codediff has no built-in way to jump straight at a diff pane — only
-- focus_explorer and the ]f/[f/]c/[c motions — so <C-w>h/l is the fallback, and
-- with the explorer open that is a window too many. These two land directly.
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

-- Keymaps are buffer-local and codediff swaps the pane buffers on every file
-- selection, so a one-shot bind at CodeDiffOpen would only survive the first
-- file. Re-bind whenever a buffer is displayed inside a diff tab.
local function bind_pane_keys_for_buffer(tabpage, bufnr)
  local lifecycle = require("codediff.ui.lifecycle")
  for _, key in ipairs(PANE_KEYS) do
    lifecycle.set_buf_keymap(tabpage, bufnr, "n", key.lhs, function()
      focus_pane(tabpage, key.side)
    end, { desc = key.desc })
  end
end

-- Translate a pre-3.0 SessionConfig into the panel/Path shape. Anything already
-- speaking the current shape passes through untouched.
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
        -- Fires for every buffer in every window; cost has to stay at one table
        -- lookup for anyone who never opens a diff.
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
        -- Counting untracked files means reading each one to count its lines;
        -- they show no +N without it.
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
