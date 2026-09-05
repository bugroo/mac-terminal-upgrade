# Conversational AI verification

Verified on September 5, 2026, on an Apple Silicon Mac using the installed
Terminal.app configuration, Codex 0.153.2, Node.js 26.3.1, and pnpm 11.5.2.

## Automated checks

| Check | Result |
| --- | --- |
| `pnpm check` | Node and Zsh syntax passed |
| `pnpm test` | 29 AI tests, installer regressions, and the PTY/ZLE scenario passed |
| `./doctor.zsh` | Installed files matched the checkout; zero failures and warnings |
| `git diff --check` | Passed before publication |

AI tests use a synthetic App Server and no live credentials. They cover general
answers, optional commands, conversation resume in fresh processes, malformed
responses, escape sequences, denied tool/approval requests, timeout, cancellation,
unsupported versions, private state, reset recovery, staging rules, persisted
learning/brief modes, suppression of command suggestions during quizzes, and
separation of untrusted learner input from trusted per-turn settings.

The installer tests preserve existing shell configuration, reject conflicting
ownership and malformed markers, verify dry-run, and exercise recoverable
uninstall in an isolated home directory. The source-information scan excludes
Git metadata and ignored package-manager runtime files, not project source.

The PTY test runs actual Zsh line editing. It verifies that questions render
answers, an extra Enter does not run a suggestion, explicit staging remains
editable, Control-C releases the shell, normal commands work afterward, AI
questions do not enter shell history, Control-O submits a question without a hash,
learning controls work, and conversation reset works.

## Live Terminal.app checks

- A fresh native Terminal window loaded the installed configuration without a
  manual launch of the Codex interface.
- A Spanish general question about the sky received an explanation; a follow-up
  identified Rayleigh scattering without repeating the topic.
- An English question about RAM and storage received an explanation. A follow-up
  retained the comparison, and a later request produced a disk-space command.
- `# /command` placed that suggestion in the prompt without running it. Only a
  separate, deliberate Enter ran the read-only `df` command.
- Consecutive responses remained in scrollback after later questions. Visual QA
  caught and fixed an earlier ZLE repaint bug: answers now print outside the line
  editor through a pending-question hook, after accepting an empty shell line.
- Learning mode explained touch, filename arguments, silent success, and timestamp
  effects in Spanish. An intentionally incorrect mkdir attempt was corrected as a
  directory-versus-file mistake without executing or staging the attempt.
- A contextual quiz withheld its solution. A live brief-mode check caught stale
  model-visible style settings after resume; fixed developer settings are now
  injected before every turn. The repeated check returned a concise ls explanation
  without an unsolicited exercise. Fixture tests now require this per-turn update.
- In the native window, Control-O submitted /quiz without a leading hash. The
  response was contextual and did not disclose or stage the command being tested.
- The README image is a fresh native window capture using live AI responses and
  real eza output. No generative image or fabricated transcript is used.

## Limits of this evidence

This is not a clean-machine installation test, an Intel-hardware test, an
independent penetration test, or a guarantee of compatibility with future
experimental App Server releases. CI does not call a live model or manipulate
Terminal.app profiles. No dedicated vulnerability scanner is configured.

The integration has no JavaScript package dependencies. Its external runtimes
and model service still have their own update, availability, and security risks.
