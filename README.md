# mac-terminal-upgrade

Keep Apple Terminal. Learn commands with an inline AI tutor, ask everyday questions, and work with readable file listings, fast navigation, and persistent workspaces.

![A real Terminal.app session with colorful listings, an AI command lesson, and a recall question](assets/terminal-session.png)

<sub>Captured from Terminal.app with the installed configuration. AI answers are live model responses, not an illustration. The demonstration uses a neutral shell prompt.</sub>

## What changes

| Everyday friction | The upgrade |
| --- | --- |
| “I want to ask a question, not memorize a command.” | Type `# your question`; get an explanation in the same terminal, then ask follow-ups |
| “I copy commands but forget what they mean.” | Learning mode explains each part, the expected result, and one small recall exercise; you control execution |
| “File listings are hard to scan.” | `ll` colors directories, permissions, sizes, file types, icons, and Git status |
| “Finding a file or project breaks my flow.” | fzf previews, `fd`, `rg`, and `zoxide` shorten navigation and search |
| “I lose my terminal workspace when I close a window.” | `work` opens or reattaches a tmux session |

This is a Zsh configuration and a small AI client, not a replacement terminal emulator. It does not reproduce Warp's native graphical blocks or change Warp.

## Install

Requirements: macOS 14 or newer, Zsh, internet access for packages and AI, and access to this private repository. Apple Silicon is the primary tested platform. Intel support has not been verified on hardware.

With GitHub CLI already installed and authenticated:

```sh
gh repo clone bugroo/mac-terminal-upgrade ~/.mac-terminal-upgrade && ~/.mac-terminal-upgrade/install.sh
```

The installer backs up existing configuration before applying changes. It installs missing Homebrew dependencies without upgrading existing packages, imports the Focus profile, and adds managed blocks to `.zshrc` and `.tmux.conf`. Open a new tab with **Command-T** after installation.

For inline AI, use your existing Codex sign-in. If needed:

```sh
codex login
```

No API key is stored in this repository. AI uses your configured Codex provider and its account limits; installing this project does not include an AI subscription or free usage.

Preview installation without changing files, packages, or Terminal settings:

```sh
~/.mac-terminal-upgrade/install.sh --dry-run
```

## Talk to AI without opening a separate interface

At the normal Zsh prompt, type:

```text
# Why is the sky blue?
# What is that phenomenon called?
# Explain it with an everyday example.
```

Each **Enter** sends a question and prints the answer in Terminal's scrollback. Follow-up questions retain context in that tab. Replies follow the language you use, including Spanish; the project documentation and interface labels are English.

Questions can be general, conceptual, or about terminal work:

```text
# What is the difference between RAM and disk storage?
# What do the letters in drwxr-xr-x mean?
# Help me understand this error: zsh: command not found: eza
# How would I list PDF files below this directory on macOS?
```

Normal commands such as `ll`, `cd`, or `git status` still run normally. Only lines beginning with `# ` enter inline AI. There is no automatic guessing between natural language and executable shell input. Inside scripts, `#` remains a comment.

**Forgot the `#`?** Before pressing Enter, press **Control-O** to send the current line to AI. If you already pressed Enter and got `command not found`, retype the question with `# `, or recall it with **Up** and press **Control-O**. Standard Control-O bindings are replaced; unrelated custom bindings are preserved.

### Learn a command, not just copy it

**Learning mode is the default.** Terminal questions get a short lesson: a simple command, its parts, its effects, and one recall challenge. General questions still get ordinary answers. The tutor distinguishes macOS/BSD tools from GNU/Linux syntax when it matters.

```text
# How do I create an empty text file called notes.txt?
```

For example, a lesson should explain that `touch notes.txt` creates the file if missing; `touch` is the command and `notes.txt` is the filename. If the file already exists, its timestamps change without erasing its contents. Success is normally silent. This behavior is documented in the local `man touch` and the [GNU touch manual](https://www.gnu.org/software/coreutils/manual/html_node/touch-invocation.html).

The tutor then asks a small variation, such as creating a different filename. **Reply to the tutor with `#`**, rather than running your answer immediately:

```text
# touch practice.txt
```

It checks the attempt and explains corrections. It cannot see whether you actually ran anything; you must provide relevant, non-sensitive output when asking about results. Exercises should not involve executing destructive or privileged commands.

| Learning control | What happens |
| --- | --- |
| `# /quiz` | Ask one recall question about a command from this conversation; no staged solution |
| `# /brief` | Switch to concise answers without automatic exercises |
| `# /learn` | Return to the default teaching style |
| `# I know touch already; explain mkdir next.` | Skip familiar material within this conversation |

The approach uses worked examples followed by retrieval practice, consistent with the [IES learning practice guide](https://ies.ed.gov/ncee/wwc/PracticeGuide/1). It is not a guarantee of retention. There is no permanent learning profile, mastery score, or automatic spaced-review scheduler. You can revisit a command later and ask for a quiz; new tabs do not remember old lessons.

### Suggestions are optional, execution is separate

For a request such as:

```text
# Show me how to check my macOS version and explain the command.
```

A typical response explains `sw_vers` and displays it as a suggestion. The actual wording can vary.

1. Read the explanation and suggestion. Nothing runs.
2. Type `# /command` and press **Enter** to put the suggestion in the editable prompt.
3. Review or edit it. Press **Enter** to execute it, or **Control-U** to discard it.

Pressing Enter on the empty prompt after an answer does **not** execute the suggestion. Suggestions are not certified safe; commands that modify files or use the network need particular care. Changing directories prevents staging a suggestion generated in the previous location.

### Conversation controls

| Input | Effect |
| --- | --- |
| `# any question` | Ask or continue this tab's conversation |
| `# /command` | Stage the last suggestion for review, without executing it |
| `# /new` | Start a new conversation; clear the pending suggestion |
| `# /help` | Show inline help and privacy boundaries |
| **Control-C** while waiting | Cancel the request and return control to Zsh |

A new terminal tab starts its own conversation in learning mode. Re-sourcing the AI module in the same shell preserves its conversation. `# /new` keeps the selected learning/brief mode and does not delete older Codex history. Mode switches are local and do not make an AI request.

The client shows a waiting message and renders the completed answer; it does not currently stream partial response text. Requests have a 60-second limit.

## Read files and move around comfortably

### Colorful listings

```sh
l                 # compact listing, icons, directories first
ll                # detailed listing: permissions, size, time, icons, Git state
lt                # directory tree, two levels deep
bat README.md     # syntax-colored file preview with line numbers
```

The Focus profile uses a dark background, light text, restrained accent colors, and JetBrains Mono Nerd Font. The font provides the glyphs used by file icons.

### Search and navigation

```sh
fd config         # find paths by name; respects .gitignore
rg 'TODO'         # search file contents
z portfolio       # jump to a frequently visited directory
```

| Shortcut | What it does |
| --- | --- |
| **Control-T** | Select files with a syntax-colored preview |
| **Control-/** inside the picker | Toggle the preview pane |
| **Option-C** | Select and enter a directory, with a tree preview |
| **Control-R** | Search shell history |
| **Control-G** | Open navi's command cheat sheets |

Option-based shortcuts depend on Terminal's Option-as-Meta setting; **Escape**, then **C** is an alternative. History suggestions and syntax highlighting complement these tools without changing normal shell execution.

### Persistent workspaces

```sh
work              # attach to the main tmux session, or create it
work portfolio    # use a named session
```

Inside tmux, press **Control-B**, release, then:

| Key | Action |
| --- | --- |
| `d` | Detach; the session keeps running |
| `c` | Open a window in the same directory |
| `|` | Split left/right |
| `-` | Split top/bottom |
| `r` | Reload tmux configuration |

Sessions survive closing a terminal window, not a Mac reboot.

### Revisit command output

Terminal.app's native prompt marks support **Command-Up/Down** to jump between prompts, **Shift-Command-A** to select output between marks, and **Command-L** to clear to the previous mark. These are native navigation aids, not Warp-style interactive blocks. Inline answers appear in ordinary scrollback.

## Optional full Codex sessions

Inline conversation does not launch the full Codex interface. These separate shortcuts remain available when you explicitly want a coding-agent session:

```sh
ai             # full Codex interface, read-only sandbox
ai-web         # full Codex interface, read-only with web search
ai-build       # full Codex interface, workspace-write permissions
ai-resume      # resume the most recent Codex session
```

These commands use the normal Codex configuration and their own permissions. They do not share the inline client's conversation-only guarantees. `ai-resume` uses Codex's latest session selection, which can include other sessions.

## AI architecture, privacy, and boundaries

The Node.js client communicates with `codex app-server` through local stdin/stdout pipes. It starts or resumes a conversation, applies the current teaching settings as a fixed developer message, sends your question as user input, validates the structured response, and returns text to Zsh. User text is never inserted into the developer message. It never evaluates model output.

- **Explicit input only:** the integration sends your questions. It does not attach shell history, directory listings, previous command output, or project files. If a question needs an error message, provide only the relevant, non-sensitive excerpt.
- **Conversation-only controls:** the child disables environment access, shell tools, MCP servers, plugins, apps, hooks, skills discovery, memory, web search, and other agent capabilities. The client requires the read-only sandbox and never grants server-initiated action requests. These are application controls, not operating-system isolation.
- **Safe display:** responses are schema-checked; terminal escape sequences are stripped. Multiline or control-character suggestions cannot be placed in the prompt. Printable shell syntax is allowed because suggestions remain text until you explicitly run them.
- **Local state:** a private per-shell temporary directory stores the conversation ID, learning/brief preference, last suggestion, and its working directory. Codex retains its conversation history under its normal storage policy. Old temporary state may remain until system cleanup; resetting the conversation is not a history deletion.
- **Provider boundary:** questions and conversational context go to your configured Codex provider. Do not paste secrets. This is not an offline assistant and it cannot browse current information or inspect your computer through inline chat.

Authentication stays managed by Codex. The integration does not copy credentials or edit global Codex configuration. It starts a child only for a request, closes it afterward, and installs no background service or network listener.

Tested with Codex **0.153.2**. Older versions are rejected. App Server is experimental; future Codex changes may require a client update. The helper requires **Node.js 22+**, included through Homebrew, and uses **zero third-party JavaScript packages**.

## What the installer manages

| Area | Managed changes |
| --- | --- |
| Terminal.app | Dedicated Focus profile, default/startup profile selection, font and palette |
| Zsh | One managed source block; aliases, completions, previews, inline conversation |
| AI | Node client and ZLE module under `~/.config/mac-terminal-upgrade/`; legacy helper guard |
| tmux | One managed source block and session/pane configuration |
| navi | Managed configuration and local cheat sheet |

Homebrew dependencies are defined in [Brewfile](Brewfile): bat, eza, fd, fzf, jq, navi, Node.js, ripgrep, tmux, zoxide, Zsh suggestions/highlighting, Codex, and JetBrains Mono Nerd Font.

Existing aliases and functions are generally preserved. Inline AI changes the standard `accept-line` widget when Enter uses that widget; a custom Enter binding can prevent activation. Existing terminal tabs keep their loaded functions until refreshed or replaced with a new tab.

Backups are stored under `~/.config/mac-terminal-upgrade-backups/`, with private permissions and checksums. They may include personal shell configuration; never commit or upload them.

## Diagnose, update, and recover

```sh
~/.mac-terminal-upgrade/doctor.zsh
~/.mac-terminal-upgrade/update.sh --dry-run
~/.mac-terminal-upgrade/update.sh
```

The doctor checks installed files, syntax, source parity, dependencies, and the Terminal profile. It is not a live model test. The updater requires a clean checkout and a tracking branch, pulls fast-forward only, makes a fresh backup, and reapplies the installation.

| Symptom | Check |
| --- | --- |
| `# question` does nothing or calls the old helper | Open a new tab; inspect `bindkey '^M'` if you have a custom Enter binding |
| Authentication error | Check `codex login status`; sign in if needed |
| Usage-limit error | Wait for the account limit to reset; re-login does not fix quotas |
| Protocol/configuration error | Run the doctor and check your Codex version; do not reset credentials |
| Missing icons or colors | Select the Focus profile and JetBrains Mono Nerd Font; use `ll` |

To refresh **only the inline integration** in an existing idle Zsh tab:

```sh
source ~/.config/mac-terminal-upgrade/zsh/terminal-ai.zsh
```

To uninstall managed configuration:

```sh
~/.mac-terminal-upgrade/uninstall.sh
```

The uninstaller removes managed shell blocks, archives installed files, restores previous default/startup Terminal profiles, and removes its dedicated profile. It preserves Homebrew packages, Codex authentication, and conversation history.

## Development and verification

Use the pinned **pnpm 11.5.2**. There are no JavaScript package dependencies or lifecycle scripts. Supply-chain settings live in [pnpm-workspace.yaml](pnpm-workspace.yaml); do not introduce npm, npx, or Yarn install flows.

```sh
pnpm install --frozen-lockfile --ignore-scripts
pnpm check
pnpm test
git diff --check
```

The test suite covers the App Server protocol with a synthetic provider, fresh-process conversation resume, learning-mode persistence, quiz staging restrictions, response validation, command staging, cancellation, timeout, unsupported versions, private state, repeated installation, preserved user configuration, recoverable uninstall, and real ZLE interaction through a PTY, including Control-O.

Tests do **not** use a live account, install Homebrew packages, or change Terminal.app profiles. The installer harness performs a scoped source-information scan. There is no dedicated vulnerability scanner configured; zero JavaScript packages does not eliminate risk in the external runtimes.

CI runs on macOS with a commit-pinned checkout action. Live conversational and visual checks on an existing Mac are separate from CI; neither proves installation on a completely clean Mac or Intel hardware.

See the [verification record](docs/verification.md) for the latest live checks and their limits.

## Official references

Implementation checked on September 5, 2026:

- [OpenAI: Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [Homebrew: installation](https://docs.brew.sh/Installation)
- [Apple: Terminal profiles](https://support.apple.com/guide/terminal/trml107/mac)
- [Apple: prompt marks](https://support.apple.com/guide/terminal/trml135fbc26/mac)
- [fzf: shell integration and previews](https://github.com/junegunn/fzf#setting-up-shell-integration)
- [eza: options, colors, and icons](https://github.com/eza-community/eza/blob/main/man/eza.1.md)
- [bat](https://github.com/sharkdp/bat) · [fd](https://github.com/sharkdp/fd) · [zoxide](https://github.com/ajeetdsouza/zoxide)
- [navi: configuration](https://github.com/denisidoro/navi/blob/master/docs/configuration/README.md)
- [tmux: getting started](https://github.com/tmux/tmux/wiki/Getting-Started)
- [Node.js: child processes](https://nodejs.org/api/child_process.html)
- [pnpm: supply-chain protections](https://pnpm.io/supply-chain-security)
