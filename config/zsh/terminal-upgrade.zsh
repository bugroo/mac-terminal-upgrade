# mac-terminal-upgrade: managed Zsh enhancements.

if [[ -n "${MAC_TERMINAL_UPGRADE_LOADED:-}" ]]; then
    return 0
fi
typeset -g MAC_TERMINAL_UPGRADE_LOADED=1

HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=50000
SAVEHIST=10000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
unsetopt BEEP

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*'
autoload -Uz compinit && compinit

if [[ -x /opt/homebrew/bin/brew ]]; then
    typeset -g terminal_upgrade_brew_prefix=/opt/homebrew
elif [[ -x /usr/local/bin/brew ]]; then
    typeset -g terminal_upgrade_brew_prefix=/usr/local
else
    typeset -g terminal_upgrade_brew_prefix=''
fi

if command -v fzf >/dev/null 2>&1; then
    if command -v fd >/dev/null 2>&1; then
        export FZF_CTRL_T_COMMAND='fd --hidden --follow --exclude .git --exclude node_modules --exclude target'
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules --exclude target'
    fi
    if command -v bat >/dev/null 2>&1; then
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null' --bind 'ctrl-/:toggle-preview'"
    fi
    if command -v eza >/dev/null 2>&1; then
        export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons=always {} 2>/dev/null | head -200'"
    fi
    source <(fzf --zsh)
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

if command -v eza >/dev/null 2>&1; then
    export EZA_ICONS_AUTO=1
    export EZA_COLORS='di=1;38;5;111:ex=1;38;5;114:ln=38;5;80:or=1;38;5;203:pi=38;5;221:so=38;5;176:bd=38;5;173:cd=38;5;173:sp=38;5;203:ur=38;5;111:uw=38;5;221:ux=38;5;114:ue=38;5;114:gr=38;5;111:gw=38;5;221:gx=38;5;114:tr=38;5;111:tw=38;5;221:tx=38;5;114:su=1;38;5;203:sf=1;38;5;203:xa=38;5;80:uu=38;5;252:gu=38;5;246:ga=38;5;114:gm=38;5;221:gd=38;5;203:gv=38;5;80:gt=38;5;176:gi=38;5;242:gc=1;38;5;203:da=38;5;245:sn=38;5;250:sb=38;5;245:xx=38;5;240'
    (( $+aliases[l] )) || alias l='eza --color=always --icons=always --group-directories-first'
    (( $+aliases[ll] )) || alias ll='eza --color=always --icons=always --group-directories-first -lah --git'
    (( $+aliases[lt] )) || alias lt='eza --color=always --icons=always --group-directories-first --tree --level=2'
fi

if [[ -n "$terminal_upgrade_brew_prefix" && -r "$terminal_upgrade_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=80
    source "$terminal_upgrade_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if command -v navi >/dev/null 2>&1; then
    export NAVI_CONFIG="$HOME/.config/mac-terminal-upgrade/navi/config.yaml"
    source <(navi widget zsh)
fi

if [[ -n "$terminal_upgrade_brew_prefix" && -r "$terminal_upgrade_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
    source "$terminal_upgrade_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    for terminal_style in ${(k)ZSH_HIGHLIGHT_STYLES}; do
        ZSH_HIGHLIGHT_STYLES[$terminal_style]='fg=default'
    done
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red'
    ZSH_HIGHLIGHT_STYLES[bracket-error]='fg=red'
    ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]='underline'
    unset terminal_style
fi

[[ -r "$HOME/.config/mac-terminal-upgrade/zsh/terminal-ai.zsh" ]] && source "$HOME/.config/mac-terminal-upgrade/zsh/terminal-ai.zsh"

if (( ! $+functions[work] && ! $+aliases[work] )); then
    function work {
        tmux new-session -A -s "${1:-main}"
    }
fi

if (( ! $+functions[ai] && ! $+aliases[ai] )); then
    function ai {
        command codex --sandbox read-only --ask-for-approval on-request --no-alt-screen "$@"
    }
fi

if (( ! $+functions[ai-web] && ! $+aliases[ai-web] )); then
    function ai-web {
        command codex --sandbox read-only --ask-for-approval on-request --search --no-alt-screen "$@"
    }
fi

if (( ! $+functions[ai-build] && ! $+aliases[ai-build] )); then
    function ai-build {
        command codex --sandbox workspace-write --ask-for-approval on-request --no-alt-screen "$@"
    }
fi

if (( ! $+functions[ai-resume] && ! $+aliases[ai-resume] )); then
    function ai-resume {
        command codex resume --last --no-alt-screen "$@"
    }
fi

unset terminal_upgrade_brew_prefix
