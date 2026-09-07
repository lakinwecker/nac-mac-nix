$env.PATH = ($env.PATH | split row (char esep) | prepend [
    ($env.HOME | path join ".local" "bin")
    ($env.HOME | path join "bin")
    ($env.HOME | path join "go" "bin")
    # npm's global prefix (see ../pi/default.nix). Deliberately after ~/bin, so
    # the `pi` wrapper keeps shadowing the binary LazyPi installs here.
    ($env.HOME | path join ".npm-global" "bin")
] | uniq)

$env.EDITOR = "nvim"
$env.CMAKE_BUILD_PARALLEL_LEVEL = "16"
$env.CMAKE_EXPORT_COMPILE_COMMANDS = "1"

# pinentry-curses needs to know which terminal to prompt on
let tty_result = (^tty | complete)
if $tty_result.exit_code == 0 {
    $env.GPG_TTY = ($tty_result.stdout | str trim)
}

# Shared ssh-agent socket across terminals
if "XDG_RUNTIME_DIR" in $env {
    $env.SSH_AUTH_SOCK = ($env.XDG_RUNTIME_DIR | path join "ssh-agent.sock")
    if not ($env.SSH_AUTH_SOCK | path exists) {
        ^ssh-agent -a $env.SSH_AUTH_SOCK out+err> /dev/null
    }
}
