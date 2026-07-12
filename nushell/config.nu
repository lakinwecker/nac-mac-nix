# Minimal, quiet startup
$env.config.show_banner = false

# Direnv integration
$env.config = ($env.config | upsert hooks.pre_prompt (
    ($env.config.hooks.pre_prompt? | default []) | append {||
        if (which direnv | is-empty) { return }
        direnv export json | from json | default {} | load-env
    }
))

# Aliases (ported from fish)
alias ta = tmux attach-session -d -t
alias tl = tmux list-sessions
alias tc = tmux
alias ls = eza
alias vim = nvim
alias vimdiff = nvim -d
alias make = ponymake
alias yarn = ponyyarn
alias fly = ponyfly
alias pnpm = ponypnpm
alias cargo = ponycargo
alias podman = ponypodman
alias bloop = ponybloop
alias cmake = ponycmake
alias invoke = ponyinvoke
alias lg = lazygit
alias cat = bat
alias gd = git diff
alias gs = git status
alias gm = git mergetool

# pass, pointed at the lichess sysadmin store
def --wrapped lipass [...rest] {
  with-env {PASSWORD_STORE_DIR: ($env.HOME | path join personal-repos lichess-org sysadmin pass)} {
    ^pass ...$rest
  }
}

# Prompt & jump
source ~/.config/nushell/starship.nu
source ~/.config/nushell/zoxide.nu

# Ghostty shell integration (symlinked from ghostty pkg by the nushell module).
# Safe to source unconditionally — the module only activates when GHOSTTY_* env vars are set.
source ~/.config/nushell/ghostty.nu
use ghostty *
