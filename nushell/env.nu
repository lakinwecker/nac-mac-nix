$env.PATH = ($env.PATH | split row (char esep) | prepend [
    ($env.HOME | path join ".local" "bin")
    ($env.HOME | path join "bin")
    ($env.HOME | path join "go" "bin")
] | uniq)

$env.EDITOR = "nvim"
$env.CMAKE_BUILD_PARALLEL_LEVEL = "16"
$env.CMAKE_EXPORT_COMPILE_COMMANDS = "1"

# Shared ssh-agent socket across terminals
if "XDG_RUNTIME_DIR" in $env {
    $env.SSH_AUTH_SOCK = ($env.XDG_RUNTIME_DIR | path join "ssh-agent.sock")
    if not ($env.SSH_AUTH_SOCK | path exists) {
        ^ssh-agent -a $env.SSH_AUTH_SOCK out+err> /dev/null
    }
}
