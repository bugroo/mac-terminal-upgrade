#!/bin/zsh

set -eu
setopt pipefail

script_dir="${0:A:h}"
target_home="${MTU_TARGET_HOME:-$HOME}"
skip_packages="${MTU_SKIP_PACKAGES:-0}"
skip_terminal="${MTU_SKIP_TERMINAL:-0}"
backup_root="$target_home/.config/mac-terminal-upgrade-backups"
timestamp="$(date '+%Y-%m-%d-%H%M%S')-$$"
backup_dir="$backup_root/$timestamp"

if [[ "$(uname -s)" != Darwin ]]; then
    print -u2 -- "Este instalador solo admite macOS."
    exit 1
fi

mkdir -p "$backup_dir"
chmod 700 "$backup_root" "$backup_dir"

backup_file() {
    local source_path="$1"
    local backup_name="$2"
    if [[ -e "$source_path" ]]; then
        cp -pR "$source_path" "$backup_dir/$backup_name"
    fi
}

backup_file "$target_home/.zshrc" zshrc
backup_file "$target_home/.tmux.conf" tmux.conf
backup_file "$target_home/.config/navi/config.yaml" navi-config.yaml
backup_file "$target_home/.config/mac-terminal-upgrade" managed-config
backup_file "$target_home/.local/bin/mac-terminal-ai-command" mac-terminal-ai-command
backup_file "$target_home/.local/share/navi/cheats/mac-terminal-upgrade.cheat" mac-terminal-upgrade.cheat
if [[ "$target_home" == "$HOME" ]]; then
    if ! defaults export com.apple.Terminal "$backup_dir/Terminal.plist" >/dev/null 2>&1; then
        backup_file "$target_home/Library/Preferences/com.apple.Terminal.plist" Terminal.plist
    fi
fi

managed_root="$target_home/.config/mac-terminal-upgrade"
install_marker="$managed_root/.installed-by-mac-terminal-upgrade"
managed_helper="$target_home/.local/bin/mac-terminal-ai-command"
managed_cheat="$target_home/.local/share/navi/cheats/mac-terminal-upgrade.cheat"
profile_name='Mac Terminal Upgrade - Focus'
profile_marker="$managed_root/terminal/profile-owned"

validate_managed_block() {
    local target_file="$1"
    local begin_marker="$2"
    local end_marker="$3"
    local begin_count end_count

    [[ -e "$target_file" ]] || return 0
    begin_count="$(awk -v marker="$begin_marker" '$0 == marker { count++ } END { print count + 0 }' "$target_file")"
    end_count="$(awk -v marker="$end_marker" '$0 == marker { count++ } END { print count + 0 }' "$target_file")"
    if [[ "$begin_count" != "$end_count" || "$begin_count" -gt 1 ]]; then
        print -u2 -- "Incomplete or duplicate managed markers in $target_file. Nothing was changed."
        return 1
    fi
    if [[ "$begin_count" == 1 ]] && ! awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin && !begin_line { begin_line = NR }
        $0 == end && !end_line { end_line = NR }
        END { exit !(begin_line < end_line) }
    ' "$target_file"; then
        print -u2 -- "Managed markers are in the wrong order in $target_file. Nothing was changed."
        return 1
    fi
}

zsh_begin='# >>> mac-terminal-upgrade >>>'
zsh_end='# <<< mac-terminal-upgrade <<<'
tmux_begin='# >>> mac-terminal-upgrade >>>'
tmux_end='# <<< mac-terminal-upgrade <<<'

validate_managed_block "$target_home/.zshrc" "$zsh_begin" "$zsh_end"
validate_managed_block "$target_home/.tmux.conf" "$tmux_begin" "$tmux_end"
if [[ -e "$target_home/.zshrc" ]] && ! zsh -n "$target_home/.zshrc"; then
    print -u2 -- "The existing Zsh configuration contains a syntax error. A backup was created, but nothing was installed."
    exit 1
fi
zsh -n "$script_dir/config/zsh/terminal-upgrade.zsh"
zsh -n "$script_dir/bin/terminal-ai-command"
plutil -lint "$script_dir/terminal/Mac-Terminal-Upgrade-Focus.terminal" >/dev/null

if [[ -d "$managed_root" && ! -e "$install_marker" ]]; then
    print -u2 -- "$managed_root already exists and is not owned by this installer. Nothing was changed."
    exit 1
fi
if [[ -e "$managed_helper" && ! -e "$install_marker" ]]; then
    print -u2 -- "$managed_helper already exists and is not owned by this installer. Nothing was changed."
    exit 1
fi
if [[ -e "$managed_cheat" && ! -e "$install_marker" ]]; then
    print -u2 -- "$managed_cheat already exists and is not owned by this installer. Nothing was changed."
    exit 1
fi
if [[ "$skip_terminal" != 1 && "$target_home" == "$HOME" ]]; then
    profile_exists="$(osascript -e 'tell application "Terminal" to exists settings set "Mac Terminal Upgrade - Focus"')"
    if [[ "$profile_exists" == true && ! -e "$profile_marker" ]]; then
        print -u2 -- "A Terminal profile named '$profile_name' already exists and is not owned by this installer."
        exit 1
    fi
fi

if [[ "$skip_packages" != 1 ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        print -- "Installing Homebrew with its official installer..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        else
            print -u2 -- "Homebrew is still unavailable after installation."
            exit 1
        fi
    fi

    print -- "Installing Terminal tools..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --no-upgrade --file "$script_dir/Brewfile"
fi

mkdir -p \
    "$managed_root/zsh" \
    "$managed_root/tmux" \
    "$managed_root/navi" \
    "$managed_root/terminal" \
    "$managed_root/terminal-ai" \
    "$target_home/.local/bin" \
    "$target_home/.local/share/navi/cheats"
printf 'managed by mac-terminal-upgrade\n' > "$install_marker"
chmod 600 "$install_marker"

install -m 600 "$script_dir/config/zsh/terminal-upgrade.zsh" "$managed_root/zsh/terminal-upgrade.zsh"
install -m 600 "$script_dir/config/tmux/terminal-upgrade.conf" "$managed_root/tmux/terminal-upgrade.conf"
install -m 600 "$script_dir/config/terminal-ai/command.schema.json" "$managed_root/terminal-ai/command.schema.json"
install -m 700 "$script_dir/bin/terminal-ai-command" "$managed_helper"
install -m 600 "$script_dir/config/navi/cheats/terminal-upgrade.cheat" "$managed_cheat"

escaped_home="${target_home//\/\\}"
escaped_home="${escaped_home//&/\\&}"
escaped_home="${escaped_home//|/\\|}"
sed "s|__HOME__|$escaped_home|g" "$script_dir/config/navi/config.yaml.template" > "$managed_root/navi/config.yaml"
chmod 600 "$managed_root/navi/config.yaml"

upsert_managed_block() {
    local target_file="$1"
    local begin_marker="$2"
    local end_marker="$3"
    local source_line="$4"
    local cleaned_file

    validate_managed_block "$target_file" "$begin_marker" "$end_marker"
    cleaned_file="$(mktemp "${TMPDIR:-/tmp}/mac-terminal-upgrade.XXXXXX")"
    [[ -e "$target_file" ]] || : > "$target_file"
    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skipping = 1; next }
        $0 == end { skipping = 0; next }
        !skipping { print }
    ' "$target_file" > "$cleaned_file"

    cp "$cleaned_file" "$target_file"
    printf '\n%s\n%s\n%s\n' "$begin_marker" "$source_line" "$end_marker" >> "$target_file"
    rm -f "$cleaned_file"
    chmod 600 "$target_file"
}

upsert_managed_block \
    "$target_home/.zshrc" \
    "$zsh_begin" \
    "$zsh_end" \
    '[[ -r "$HOME/.config/mac-terminal-upgrade/zsh/terminal-upgrade.zsh" ]] && source "$HOME/.config/mac-terminal-upgrade/zsh/terminal-upgrade.zsh"'

upsert_managed_block \
    "$target_home/.tmux.conf" \
    "$tmux_begin" \
    "$tmux_end" \
    'source-file ~/.config/mac-terminal-upgrade/tmux/terminal-upgrade.conf'

zsh -n "$target_home/.zshrc"
zsh -n "$managed_root/zsh/terminal-upgrade.zsh"
zsh -n "$managed_helper"

if [[ "$skip_terminal" != 1 && "$target_home" == "$HOME" ]]; then
    if [[ ! -e "$managed_root/terminal/previous-default" ]]; then
        osascript -e 'tell application "Terminal" to get name of default settings' > "$managed_root/terminal/previous-default"
        osascript -e 'tell application "Terminal" to get name of startup settings' > "$managed_root/terminal/previous-startup"
        chmod 600 "$managed_root/terminal/previous-default" "$managed_root/terminal/previous-startup"
    fi

    profile_exists="$(osascript -e 'tell application "Terminal" to exists settings set "Mac Terminal Upgrade - Focus"')"
    if [[ "$profile_exists" != true ]]; then
        open -a Terminal "$script_dir/terminal/Mac-Terminal-Upgrade-Focus.terminal"
        for attempt in {1..20}; do
            profile_exists="$(osascript -e 'tell application "Terminal" to exists settings set "Mac Terminal Upgrade - Focus"')"
            [[ "$profile_exists" == true ]] && break
            sleep 0.25
        done
    fi

    if [[ "$profile_exists" != true ]]; then
        print -u2 -- "The Focus profile could not be imported into Terminal.app."
        exit 1
    fi
    printf '%s\n' "$profile_name" > "$profile_marker"
    chmod 600 "$profile_marker"
    osascript "$script_dir/scripts/configure-terminal.applescript" "$profile_name" >/dev/null
fi

if [[ "$target_home" == "$HOME" ]] && command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$target_home/.tmux.conf"
fi

find "$backup_dir" -type f ! -name CHECKSUMS.sha256 -exec shasum -a 256 {} \; > "$backup_dir/CHECKSUMS.sha256"
chmod -R go-rwx "$backup_dir"

print -- ""
print -- "Installation complete."
print -- "Backup: $backup_dir"
print -- "Open a new tab with Command-T."
print -- "Inline AI: type '# describe the command' and press Enter."
