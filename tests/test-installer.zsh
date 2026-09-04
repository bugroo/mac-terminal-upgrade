#!/bin/zsh

set -eu
setopt pipefail

repo_dir="${0:A:h:h}"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/mac-terminal-upgrade-test.XXXXXX")"

mkdir -p "$test_root"
printf '# configuración previa\nalias original="printf original"\n' > "$test_root/.zshrc"
printf '# tmux previo\nset -g mouse off\n' > "$test_root/.tmux.conf"

MTU_TARGET_HOME="$test_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null
MTU_TARGET_HOME="$test_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null

[[ "$(rg -c '^# >>> mac-terminal-upgrade >>>$' "$test_root/.zshrc")" == 1 ]]
[[ "$(rg -c '^# >>> mac-terminal-upgrade >>>$' "$test_root/.tmux.conf")" == 1 ]]
rg -q 'alias original=' "$test_root/.zshrc"
rg -q 'set -g mouse off' "$test_root/.tmux.conf"
[[ -x "$test_root/.local/bin/mac-terminal-ai-command" ]]
[[ -r "$test_root/.config/mac-terminal-upgrade/terminal-ai/command.schema.json" ]]
[[ -r "$test_root/.local/share/navi/cheats/mac-terminal-upgrade.cheat" ]]
zsh -n "$test_root/.zshrc"
zsh -n "$test_root/.config/mac-terminal-upgrade/zsh/terminal-upgrade.zsh"
zsh -n "$test_root/.local/bin/mac-terminal-ai-command"
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

fake_bin="$test_root/fake-bin"
mkdir -p "$fake_bin"
{
    print '#!/bin/zsh'
    print 'while (( $# )); do'
    print '    if [[ "$1" == --output-last-message ]]; then shift; output_file="$1"; fi'
    print '    shift'
    print 'done'
    print 'jq -n --arg command "$FAKE_CODEX_COMMAND" '\''{command: $command}'\'' > "$output_file"'
} > "$fake_bin/codex"
chmod 700 "$fake_bin/codex"

ask_fake() {
    FAKE_CODEX_COMMAND="$1" \
    PATH="$fake_bin:$PATH" \
    TERMINAL_AI_SCHEMA="$test_root/.config/mac-terminal-upgrade/terminal-ai/command.schema.json" \
    "$test_root/.local/bin/mac-terminal-ai-command" 'prueba'
}

[[ "$(ask_fake 'df -h /')" == 'df -h /' ]]
[[ "$(ask_fake $'rm\t-rf /')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'find . -delete')" == '# REFUSED:'* ]]
[[ "$(ask_fake "find . -'delete'")" == '# REFUSED:'* ]]
[[ "$(ask_fake 'rg --pre sh secreto')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'ls & rm -rf /')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'ls !!')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'git grep --open-files-in-pager=sh needle')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'git diff --ext-diff')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'sysctl kern.maxfiles=123')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'sysctl -f settings.conf')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'sysctl -if settings.conf')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'sort -uo out input')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'du -ah . | sort -hr | head')" == 'du -ah . | sort -hr | head' ]]
[[ "$(ask_fake $'# REFUSED: motivo\ndate')" == '# REFUSED: la propuesta no pasó la política local de solo lectura' ]]
[[ "$(ask_fake $'# REFUSED: motivo\tdate')" == '# REFUSED: la propuesta no pasó la política local de solo lectura' ]]
[[ "$(ask_fake $'ls \e[31m')" == '# REFUSED:'* ]]
[[ "$(ask_fake $'ls \vdate')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'find . *')" == '# REFUSED:'* ]]
[[ "$(ask_fake 'git status --short')" == 'git status --short' ]]

broken_root="$test_root-broken"
mkdir -p "$broken_root"
printf '%s\n%s\n' '# >>> mac-terminal-upgrade >>>' 'NO BORRAR ESTA COLA' > "$broken_root/.zshrc"
cp "$broken_root/.zshrc" "$broken_root/.zshrc.expected"
if MTU_TARGET_HOME="$broken_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null 2>&1; then
    print -u2 -- "El instalador aceptó marcadores incompletos."
    exit 1
fi
cmp "$broken_root/.zshrc.expected" "$broken_root/.zshrc"
[[ ! -e "$broken_root/.config/mac-terminal-upgrade/.installed-by-mac-terminal-upgrade" ]]

collision_root="$test_root-collision"
mkdir -p "$collision_root/.local/bin"
printf 'archivo ajeno\n' > "$collision_root/.local/bin/mac-terminal-ai-command"
if MTU_TARGET_HOME="$collision_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null 2>&1; then
    print -u2 -- "El instalador sobrescribió un archivo ajeno."
    exit 1
fi
rg -q '^archivo ajeno$' "$collision_root/.local/bin/mac-terminal-ai-command"

invalid_root="$test_root-invalid-zsh"
mkdir -p "$invalid_root"
printf '%s\n' 'if {' 'NO BORRAR ESTA COLA' > "$invalid_root/.zshrc"
cp "$invalid_root/.zshrc" "$invalid_root/.zshrc.expected"
if MTU_TARGET_HOME="$invalid_root" MTU_SKIP_PACKAGES=1 MTU_SKIP_TERMINAL=1 "$repo_dir/install.sh" >/dev/null 2>&1; then
    print -u2 -- "El instalador aceptó una .zshrc inválida."
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
    print -u2 -- "La desinstalación aceptó marcadores incompletos."
    exit 1
fi
cmp "$partial_root/.zshrc.expected" "$partial_root/.zshrc"
[[ -e "$partial_root/.config/mac-terminal-upgrade/.installed-by-mac-terminal-upgrade" ]]

if rg -n '/Users/rootml|gho_|OPENAI_API_KEY|ANTHROPIC_API_KEY' "$repo_dir" --glob '!tests/test-installer.zsh'; then
    print -u2 -- "Se encontró información local o sensible en el repositorio."
    exit 1
fi

MTU_TARGET_HOME="$test_root" "$repo_dir/uninstall.sh" >/dev/null
! rg -q '^# >>> mac-terminal-upgrade >>>$' "$test_root/.zshrc"
! rg -q '^# >>> mac-terminal-upgrade >>>$' "$test_root/.tmux.conf"
rg -q 'alias original=' "$test_root/.zshrc"
rg -q 'set -g mouse off' "$test_root/.tmux.conf"

print -- "OK: instalación repetible, configuración preservada y desinstalación recuperable."
print -- "Directorio de prueba: $test_root"
