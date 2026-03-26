. ~/.config/fish/aliases.fish

set -x PATH $PATH /home/lakin/.local/bin
set -x PATH $PATH /home/lakin/bin
set -x PATH $PATH /home/lakin/go/bin
set -x EDITOR nvim
set -x CMAKE_BUILD_PARALLEL_LEVEL 16
set -x CMAKE_EXPORT_COMPILE_COMMANDS 1
set fish_greeting

# Start ssh-agent if not already running, shared across terminals
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.sock"
if not test -S $SSH_AUTH_SOCK
    eval (ssh-agent -c -a $SSH_AUTH_SOCK) >/dev/null 2>&1
end

starship init fish | source
zoxide init fish | source

function envsource
    for line in (cat $argv | grep -v '^#')
        set item (string split -m 1 '=' $line)
        set -gx $item[1] $item[2]
        echo "Exported key $item[1]"
    end
end
