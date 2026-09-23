-- Loaded by LazyVim after its own lazyvim/config/options.lua, which sets
-- vim.g.snacks_animate = true. That variable is the master switch every snacks
-- animation falls back to (snacks/animate/init.lua: Snacks.animate.enabled),
-- so per-module opts in lua/plugins/snacks.lua cannot reach it -- it is read
-- from vim.g, not from the merged plugin opts.
vim.g.snacks_animate = false
