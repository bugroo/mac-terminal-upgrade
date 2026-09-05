#!/bin/zsh

set -eu
setopt pipefail

script_dir="${0:A:h}"
target_home="${MTU_TARGET_HOME:-$HOME}"
backup_root="$target_home/.config/mac-terminal-upgrade-backups"
timestamp="$(date '+%Y-%m-%d-%H%M%S')-$$-uninstall"
backup_dir="$backup_root/$timestamp"
managed_root="$target_home/.config/mac-terminal-upgrade"
install_marker="$managed_root/.installed-by-mac-terminal-upgrade"

if [[ ! -e "$install_marker" ]]; then
    print -u2 -- "No managed mac-terminal-upgrade installation was found."
    exit 1
fi

mkdir -p "$backup_dir"
chmod 700 "$backup_root" "$backup_dir"

validate_managed_block() {
    local target_file="$1"
    local begin_marker='# >>> mac-terminal-upgrade >>>'
    local end_marker='# <<< mac-terminal-upgrade <<<'
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

validate_managed_block "$target_home/.zshrc"
validate_managed_block "$target_home/.tmux.conf"

remove_managed_block() {
    local target_file="$1"
    local begin_marker='# >>> mac-terminal-upgrade >>>'
    local end_marker='# <<< mac-terminal-upgrade <<<'
    local cleaned_file

    [[ -e "$target_file" ]] || return 0
    cleaned_file="$(mktemp "${TMPDIR:-/tmp}/mac-terminal-upgrade-uninstall.XXXXXX")"
    cp -p "$target_file" "$backup_dir/$(basename "$target_file").before-uninstall"
    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skipping = 1; next }
        $0 == end { skipping = 0; next }
        !skipping { print }
    ' "$target_file" > "$cleaned_file"
    cp "$cleaned_file" "$target_file"
    rm -f "$cleaned_file"
}

remove_managed_block "$target_home/.zshrc"
remove_managed_block "$target_home/.tmux.conf"

if [[ "$target_home" == "$HOME" && -r "$managed_root/terminal/profile-owned" && -r "$managed_root/terminal/previous-default" && -r "$managed_root/terminal/previous-startup" ]]; then
    previous_default="$(<"$managed_root/terminal/previous-default")"
    previous_startup="$(<"$managed_root/terminal/previous-startup")"
    installed_profile="$(<"$managed_root/terminal/profile-owned")"
    osascript "$script_dir/scripts/restore-terminal.applescript" "$previous_default" "$previous_startup" "$installed_profile" >/dev/null
fi

if [[ -d "$managed_root" ]]; then
    mv "$managed_root" "$backup_dir/removed-managed-config"
fi

if [[ -e "$target_home/.local/bin/mac-terminal-ai-command" ]]; then
    mv "$target_home/.local/bin/mac-terminal-ai-command" "$backup_dir/mac-terminal-ai-command"
fi

if [[ -e "$target_home/.local/share/navi/cheats/mac-terminal-upgrade.cheat" ]]; then
    mv "$target_home/.local/share/navi/cheats/mac-terminal-upgrade.cheat" "$backup_dir/mac-terminal-upgrade.cheat"
fi

chmod -R go-rwx "$backup_dir"

print -- "Shell configuration removed."
print -- "Recoverable files: $backup_dir"
print -- "Homebrew packages were preserved; previous profiles were restored and the installed profile was removed."
