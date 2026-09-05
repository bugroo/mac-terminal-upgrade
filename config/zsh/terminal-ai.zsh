# Conversational AI in Zsh. Safe to source again in an existing idle tab.
setopt INTERACTIVE_COMMENTS

_terminal_ai_request_json() {
    if ! command -v node >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        print -r -- 'AI: node and jq are required; run the installer'
        return 1
    fi
    if [[ -z "${MTU_AI_STATE_DIR:-}" ]]; then
        print -r -- 'AI state is unavailable; try again in a new tab'
        return 1
    fi
    local mtu_helper="$HOME/.config/mac-terminal-upgrade/terminal-ai/terminal-ai-chat.mjs"
    # printf is a builtin: questions do not enter subprocess argv or shell history.
    builtin printf '%s' "$1" | command node "$mtu_helper" --state-dir "$MTU_AI_STATE_DIR" 2>&1
}

_terminal_ai_prepare_state() {
    if [[ -z "${MTU_AI_STATE_DIR:-}" ]]; then
        typeset -g MTU_AI_STATE_DIR
        MTU_AI_STATE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mtu-chat.XXXXXX")" || return 1
        chmod 700 "$MTU_AI_STATE_DIR"
    fi
}

_terminal_ai_valid_json() {
    builtin printf '%s' "$1" | jq -e 'type == "object" and (.answer | type == "string") and (.command == null or (.command | type == "string"))' >/dev/null 2>&1
}

_terminal_ai_chat_widget() {
    local mtu_request="${BUFFER#\# }"
    [[ -n "${mtu_request//[[:space:]]/}" ]] || { zle -M 'AI: type a question after #'; return 0; }
    _terminal_ai_prepare_state || { zle -M 'AI could not create private state'; return 0; }
    if [[ "$mtu_request" == /command ]]; then
        local mtu_result mtu_command
        mtu_result="$(_terminal_ai_request_json /command)"
        if (( $? != 0 )); then
            zle -M "$mtu_result"
            return 0
        fi
        _terminal_ai_valid_json "$mtu_result" || { zle -M 'Invalid AI response; nothing was staged'; return 0; }
        mtu_command="$(builtin printf '%s' "$mtu_result" | jq -r '.command // empty')"
        BUFFER="$mtu_command"
        CURSOR=${#BUFFER}
        zle -M "$(builtin printf '%s' "$mtu_result" | jq -r .answer)"
        zle redisplay
        return 0
    fi

    # Leave the line editor before printing durable conversation output. Drawing
    # multiline responses inside ZLE conflicts with its transient message area.
    # Only an empty shell line is accepted; no user/model text becomes shell code.
    typeset -g _MTU_AI_PENDING="$mtu_request"
    BUFFER=''
    zle .accept-line
}

_terminal_ai_flush_pending() {
    (( ${+_MTU_AI_PENDING} )) || return 0
    local mtu_request="$_MTU_AI_PENDING"
    unset _MTU_AI_PENDING
    local mtu_result mtu_rc mtu_answer mtu_command
    print -r -- "You: $mtu_request"
    builtin printf 'AI: thinking; Control-C cancels (60-second limit)'
    mtu_result="$(_terminal_ai_request_json "$mtu_request")"
    mtu_rc=$?
    builtin printf '\r\033[K'
    if (( mtu_rc != 0 )); then
        print -r -- "${mtu_result:-AI request cancelled. Nothing was executed.}"
        return 0
    fi
    if ! _terminal_ai_valid_json "$mtu_result"; then
        print -r -- 'Invalid AI response; nothing was staged.'
        return 0
    fi
    mtu_answer="$(builtin printf '%s' "$mtu_result" | jq -r .answer)"
    mtu_command="$(builtin printf '%s' "$mtu_result" | jq -r '.command // empty')"
    print -P -- '%F{111}AI%f'
    print -r -- "$mtu_answer"
    if [[ -n "$mtu_command" ]]; then
        print -r -- ""
        print -P -- '%F{221}Suggested command — not executed:%f'
        print -r -- "  $mtu_command"
        print -r -- 'Type # /command to review it in the prompt. Enter then executes it.'
    fi
    print -r -- ""
    return 0
}

_terminal_ai_accept_line() {
    if [[ "$BUFFER" == '# '* ]]; then
        _terminal_ai_chat_widget
    else
        zle .accept-line
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _terminal_ai_flush_pending
zle -N terminal-ai-chat _terminal_ai_chat_widget
# Existing Control-O bindings to the old widget name keep working.
zle -N terminal-ai-command _terminal_ai_chat_widget
# Reserve the standard Control-O binding, but preserve unrelated custom widgets.
for mtu_keymap in emacs viins; do
    case "$(bindkey -M "$mtu_keymap" '^O')" in
        *' undefined-key'|*' accept-line-and-down-history'|*' terminal-ai-command'|*' terminal-ai-chat')
            bindkey -M "$mtu_keymap" '^O' terminal-ai-chat ;;
    esac
done
unset mtu_keymap
if [[ "$(bindkey '^M')" == *' accept-line' ]]; then
    zle -N accept-line _terminal_ai_accept_line
fi
