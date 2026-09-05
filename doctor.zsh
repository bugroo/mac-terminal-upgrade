#!/bin/zsh

set -u
setopt pipefail

repo_dir="${0:A:h}"
target_home="${MTU_TARGET_HOME:-$HOME}"
skip_packages="${MTU_SKIP_PACKAGES:-0}"
skip_terminal="${MTU_SKIP_TERMINAL:-0}"
managed_root="$target_home/.config/mac-terminal-upgrade"
typeset -i failures=0
typeset -i warnings=0

pass() {
    print -- "OK    $1"
}

warn() {
    print -- "WARN  $1"
    (( warnings++ ))
}

fail() {
    print -- "FAIL  $1"
    (( failures++ ))
}

check_file() {
    local file_path="$1"
    local label="$2"
    if [[ -r "$file_path" ]]; then
        pass "$label"
    else
        fail "$label is missing or unreadable: $file_path"
    fi
}

check_syntax() {
    local file_path="$1"
    local label="$2"
    if [[ ! -r "$file_path" ]]; then
        fail "$label is missing or unreadable: $file_path"
    elif zsh -n "$file_path" >/dev/null 2>&1; then
        pass "$label syntax"
    else
        fail "$label contains a Zsh syntax error: $file_path"
    fi
}

check_managed_block() {
    local file_path="$1"
    local label="$2"
    local begin_marker='# >>> mac-terminal-upgrade >>>'
    local end_marker='# <<< mac-terminal-upgrade <<<'
    local begin_count end_count

    if [[ ! -r "$file_path" ]]; then
        fail "$label is missing or unreadable: $file_path"
        return
    fi
    begin_count="$(awk -v marker="$begin_marker" '$0 == marker { count++ } END { print count + 0 }' "$file_path")"
    end_count="$(awk -v marker="$end_marker" '$0 == marker { count++ } END { print count + 0 }' "$file_path")"
    if [[ "$begin_count" == 1 && "$end_count" == 1 ]] && awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { begin_line = NR }
        $0 == end { end_line = NR }
        END { exit !(begin_line < end_line) }
    ' "$file_path"; then
        pass "$label"
    else
        fail "$label is incomplete, duplicated, or out of order"
    fi
}

print -- "mac-terminal-upgrade doctor"
print -- "Target home: $target_home"
print -- ""

if [[ "$(uname -s)" == Darwin ]]; then
    pass "macOS host"
else
    fail "unsupported operating system: $(uname -s)"
fi

check_syntax "$repo_dir/install.sh" "Installer"
check_syntax "$repo_dir/uninstall.sh" "Uninstaller"
check_syntax "$repo_dir/update.sh" "Updater"
check_syntax "$repo_dir/config/zsh/terminal-upgrade.zsh" "Repository Zsh integration"
check_syntax "$repo_dir/config/zsh/terminal-ai.zsh" "Repository conversational AI integration"
if plutil -lint "$repo_dir/terminal/Mac-Terminal-Upgrade-Focus.terminal" >/dev/null 2>&1; then
    pass "Terminal profile plist"
else
    fail "Terminal profile plist is invalid"
fi

if [[ -r "$managed_root/.installed-by-mac-terminal-upgrade" ]]; then
    pass "managed installation marker"
else
    fail "managed installation marker is missing"
fi

check_syntax "$target_home/.zshrc" "User .zshrc"
check_syntax "$managed_root/zsh/terminal-upgrade.zsh" "Installed Zsh integration"
check_file "$managed_root/tmux/terminal-upgrade.conf" "installed tmux configuration"
check_file "$target_home/.local/bin/mac-terminal-ai-command" "inline AI helper"
check_syntax "$managed_root/zsh/terminal-ai.zsh" "Installed conversational AI integration"
check_file "$managed_root/terminal-ai/terminal-ai-chat.mjs" "conversational AI client"
if command -v node >/dev/null 2>&1; then
    if node --check "$managed_root/terminal-ai/terminal-ai-chat.mjs" >/dev/null 2>&1; then
        pass "conversational AI client syntax"
    else
        fail "conversational AI client syntax"
    fi
else
    fail "Node.js is unavailable"
fi
if [[ "$skip_packages" != 1 ]]; then
    if node --input-type=module -e 'import(process.argv[2]).then(m => m.checkVersion()).catch(() => process.exit(1))' mtu-version-check "$managed_root/terminal-ai/terminal-ai-chat.mjs" >/dev/null 2>&1; then
        pass "Codex version supports the inline protocol"
    else
        fail "inline AI requires Codex 0.153.2 or newer"
    fi
fi
for ai_item in zsh/terminal-ai.zsh terminal-ai/terminal-ai-chat.mjs; do
    if [[ "$ai_item" == zsh/* ]]; then
        ai_source="$repo_dir/config/$ai_item"
    else
        ai_source="$repo_dir/bin/terminal-ai-chat.mjs"
    fi
    if cmp -s "$ai_source" "$managed_root/$ai_item"; then
        pass "installed $ai_item matches checkout"
    else
        fail "installed $ai_item differs from checkout"
    fi
done
check_file "$target_home/.local/share/navi/cheats/mac-terminal-upgrade.cheat" "navi cheat sheet"

check_managed_block "$target_home/.zshrc" "managed .zshrc block"
check_managed_block "$target_home/.tmux.conf" "managed .tmux.conf block"

if [[ -r "$managed_root/zsh/terminal-upgrade.zsh" ]] && ! cmp -s "$repo_dir/config/zsh/terminal-upgrade.zsh" "$managed_root/zsh/terminal-upgrade.zsh"; then
    warn "installed Zsh integration differs from this checkout; run ./update.sh"
fi

if [[ "$skip_packages" == 1 ]]; then
    warn "package checks skipped by MTU_SKIP_PACKAGES=1"
elif ! command -v brew >/dev/null 2>&1; then
    fail "Homebrew is unavailable"
elif HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --file "$repo_dir/Brewfile" >/dev/null 2>&1; then
    pass "all Brewfile dependencies"
else
    fail "one or more Brewfile dependencies are missing"
fi

if [[ "$skip_terminal" == 1 || "$target_home" != "$HOME" ]]; then
    warn "Terminal.app profile check skipped"
else
    profile_exists="$(osascript -e 'tell application "Terminal" to exists settings set "Mac-Terminal-Upgrade-Focus"' 2>/dev/null || print false)"
    if [[ "$profile_exists" == true ]]; then
        pass "Focus profile in Terminal.app"
    else
        fail "Focus profile is missing from Terminal.app"
    fi
fi

print -- ""
print -- "Doctor result: $failures failure(s), $warnings warning(s)."
(( failures == 0 ))
