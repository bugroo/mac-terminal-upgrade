#!/bin/zsh

set -eu
setopt pipefail

repo_dir="${0:A:h:h}"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/mac-terminal-upgrade-test.XXXXXX")"

mkdir -p "$test_root"
printf '# existing configuration\nalias original="printf original"\n' > "$test_root/.zshrc"
printf '# existing tmux configuration\nset -g mouse off\n' > "$test_root/.tmux.conf"

cp "$test_root/.zshrc" "$test_root/.zshrc.before-dry-run"
cp "$test_root/.tmux.conf" "$test_root/.tmux.conf.before-dry-run"
dry_run_output="$(MTU_TARGET_HOME="$test_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" --dry-run)"
[[ "$dry_run_output" == *'Dry run complete: no files, packages, or Terminal settings were changed.'* ]]
cmp "$test_root/.zshrc.before-dry-run" "$test_root/.zshrc"
cmp "$test_root/.tmux.conf.before-dry-run" "$test_root/.tmux.conf"
[[ ! -e "$test_root/.config/mac-terminal-upgrade/.installed-by-mac-terminal-upgrade" ]]
[[ ! -d "$test_root/.config/mac-terminal-upgrade-backups" ]]

MTU_TARGET_HOME="$test_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null
MTU_TARGET_HOME="$test_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null

[[ "$(grep -c '^# >>> mac-terminal-upgrade >>>$' "$test_root/.zshrc")" == 1 ]]
[[ "$(grep -c '^# >>> mac-terminal-upgrade >>>$' "$test_root/.tmux.conf")" == 1 ]]
grep -q 'alias original=' "$test_root/.zshrc"
grep -q 'set -g mouse off' "$test_root/.tmux.conf"
[[ -x "$test_root/.local/bin/mac-terminal-ai-command" ]]
[[ -r "$test_root/.config/mac-terminal-upgrade/terminal-ai/command.schema.json" ]]
[[ -r "$test_root/.local/share/navi/cheats/mac-terminal-upgrade.cheat" ]]
zsh -n "$test_root/.zshrc"
zsh -n "$test_root/.config/mac-terminal-upgrade/zsh/terminal-upgrade.zsh"
zsh -n "$test_root/.local/bin/mac-terminal-ai-command"
MTU_TARGET_HOME="$test_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/doctor.zsh" >/dev/null
HOME="$test_root" PATH="/usr/bin:/bin" /bin/zsh -df -c '
    alias work="printf alias-work"
    alias ai="printf alias-ai"
    alias ai-web="printf alias-ai-web"
    alias ai-build="printf alias-ai-build"
    alias ai-resume="printf alias-ai-resume"
    source "$1"
    [[ "$(alias work)" == *"printf alias-work"* ]]
    [[ "$(alias ai)" == *"printf alias-ai"* ]]
' test-shell "$test_root/.config/mac-terminal-upgrade/zsh/terminal-upgrade.zsh"

feature_bin="$test_root/feature-bin"
mkdir -p "$feature_bin"
for feature_command in fd bat eza; do
    printf '#!/bin/zsh\nexit 0\n' > "$feature_bin/$feature_command"
    chmod 700 "$feature_bin/$feature_command"
done
printf '#!/bin/zsh\n[[ "$1" == --zsh ]] && print ":"\n' > "$feature_bin/fzf"
chmod 700 "$feature_bin/fzf"
HOME="$test_root" PATH="$feature_bin:/usr/bin:/bin" /bin/zsh -df -c '
    source "$1"
    [[ "$FZF_CTRL_T_COMMAND" == fd\ --hidden* ]]
    [[ "$FZF_ALT_C_COMMAND" == fd\ --type\ d* ]]
    [[ "$FZF_CTRL_T_OPTS" == *bat*toggle-preview* ]]
    [[ "$FZF_ALT_C_OPTS" == *eza* ]]
' test-fzf "$test_root/.config/mac-terminal-upgrade/zsh/terminal-upgrade.zsh"

# Old tabs fail safely until their line-editor integration is refreshed.
if "$test_root/.local/bin/mac-terminal-ai-command" 'test request' >/dev/null 2>&1; then
    print -u2 -- "The retired command-only helper still accepted a request."
    exit 1
fi
[[ -r "$test_root/.config/mac-terminal-upgrade/zsh/terminal-ai.zsh" ]]
node --check "$test_root/.config/mac-terminal-upgrade/terminal-ai/terminal-ai-chat.mjs"

broken_root="$test_root-broken"
mkdir -p "$broken_root"
printf '%s\n%s\n' '# >>> mac-terminal-upgrade >>>' 'DO NOT REMOVE THIS TRAILING LINE' > "$broken_root/.zshrc"
cp "$broken_root/.zshrc" "$broken_root/.zshrc.expected"
if MTU_TARGET_HOME="$broken_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null 2>&1; then
    print -u2 -- "The installer accepted incomplete markers."
    exit 1
fi
cmp "$broken_root/.zshrc.expected" "$broken_root/.zshrc"
[[ ! -e "$broken_root/.config/mac-terminal-upgrade/.installed-by-mac-terminal-upgrade" ]]

collision_root="$test_root-collision"
mkdir -p "$collision_root/.local/bin"
printf 'unmanaged file\n' > "$collision_root/.local/bin/mac-terminal-ai-command"
if MTU_TARGET_HOME="$collision_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null 2>&1; then
    print -u2 -- "The installer overwrote an unmanaged file."
    exit 1
fi
grep -q '^unmanaged file$' "$collision_root/.local/bin/mac-terminal-ai-command"

invalid_root="$test_root-invalid-zsh"
mkdir -p "$invalid_root"
printf '%s\n' 'if {' 'DO NOT REMOVE THIS TRAILING LINE' > "$invalid_root/.zshrc"
cp "$invalid_root/.zshrc" "$invalid_root/.zshrc.expected"
if MTU_TARGET_HOME="$invalid_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null 2>&1; then
    print -u2 -- "The installer accepted an invalid .zshrc."
    exit 1
fi
cmp "$invalid_root/.zshrc.expected" "$invalid_root/.zshrc"
[[ ! -e "$invalid_root/.config/mac-terminal-upgrade/.installed-by-mac-terminal-upgrade" ]]

partial_root="$test_root-partial-uninstall"
mkdir -p "$partial_root"
MTU_TARGET_HOME="$partial_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null
cp "$partial_root/.zshrc" "$partial_root/.zshrc.expected"
sed -i '' '/^# <<< mac-terminal-upgrade <<<$/{d;}' "$partial_root/.tmux.conf"
if MTU_TARGET_HOME="$partial_root" "$repo_dir/uninstall.sh" >/dev/null 2>&1; then
    print -u2 -- "The uninstaller accepted incomplete markers."
    exit 1
fi
cmp "$partial_root/.zshrc.expected" "$partial_root/.zshrc"
[[ -e "$partial_root/.config/mac-terminal-upgrade/.installed-by-mac-terminal-upgrade" ]]

if grep -RInE --exclude='test-installer.zsh' --exclude-dir='.git' --exclude-dir='node_modules' '/Users/rootml|gho_|OPENAI_API_KEY|ANTHROPIC_API_KEY' "$repo_dir"; then
    print -u2 -- "Local or sensitive information was found in the repository."
    exit 1
fi

MTU_TARGET_HOME="$test_root" "$repo_dir/uninstall.sh" >/dev/null
! grep -q '^# >>> mac-terminal-upgrade >>>$' "$test_root/.zshrc"
! grep -q '^# >>> mac-terminal-upgrade >>>$' "$test_root/.tmux.conf"
grep -q 'alias original=' "$test_root/.zshrc"
grep -q 'set -g mouse off' "$test_root/.tmux.conf"

print -- "OK: repeatable installation, preserved configuration, and recoverable uninstall."
print -- "Test directory: $test_root"
