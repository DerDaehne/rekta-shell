# rekta-shell — guide for agents

**What this is:** a desktop shell for KDE Plasma 6 on Wayland, built with
Quickshell on KWin, that follows Rekta Design strictly. It runs as a session of
its own next to the regular Plasma session and is distributed as a Nix flake.

**Status:** early development.

**Also read `CLAUDE.local.md` if it exists** — it holds the internal, non-public
working information (board, knowledge base, local environment). It is gitignored.

## Top design goal: strict Rekta fidelity (binding)

- Every visible surface and every motion traces back to a place in Rekta Design
  (its docs and tokens at the pinned commit). Colours, sizes, durations, curves
  and angles come from the generated token module, never as constants in code.
- Where Rekta says nothing or contradicts itself, do not invent: report it to
  Rekta Design and wait. Phrase such reports for every platform — Rekta Design
  stays independent of languages, frameworks and tools; this shell is only one
  implementation of it.
- Deliberate deviations from Rekta only with an ADR (example: the typeface).

## Never touch the running system (binding)

The maintainer's machine must stay usable at all times. The flake is imported
into the maintainer's NixOS configuration later, by the maintainer.

- No `nixos-rebuild`, `home-manager switch` or `nix profile install`; no writes
  to the real `~/.config`, `~/.local` or `/etc`; no `systemctl` on session units;
  no changes to the running Plasma session.
- Build and check with `nix build` and `nix flake check`. Run the shell only in a
  nested KWin session with an isolated `HOME`, or in a VM built from the flake.
- Stop every process you started (nested KWin, quickshell, VMs) before finishing.
- NixOS and home-manager modules are opt-in: every option defaults to off, so
  importing the flake changes nothing until a configuration enables it.

## Public repository — privacy (binding)

This repository is public. **Never** put into files, commits or commit messages:
names of people, email addresses, passwords, API keys/tokens, local paths,
hostnames, IP addresses, hardware or setup details (monitors, GPUs, devices), or
internal board content (ticket comments, note slugs, board columns). Ticket
numbers appear only in commit subjects as `(#<id>)`. Device and user values are
module options, never defaults in code. Personal and internal information
belongs in `CLAUDE.local.md`.

- Before every commit run `scripts/scan-secrets.sh` (gitleaks; built-in checks
  for board references, German comments, local home paths and non-noreply
  identities; privacy scan against the local `.privacy-patterns`) and check the
  diff. CI runs the same checks without the private patterns.
- **Never read, copy or symlink `.privacy-patterns`** — not even to get the scan
  to run fully in a worktree: it finds the main checkout's copy on its own, and a
  hit is always reported as file/line/commit plus a pattern number, never the
  pattern text itself.
- Push to the public remote only `main`, only after "Review ok" and a clean scan.

## Code style (binding)

People should understand intent and behaviour by reading the code.

- **Readable code over comments.** Express intent through clear names, small
  well-named functions or components, explicit types and straightforward control
  flow.
- **Shallow nesting:** at most 2 levels of nested blocks inside a function, 3
  only as a justified exception. Flatten with early returns and extracted
  functions.
- **Short functions:** a function fits on one normal screen (about 40 lines).
- **Comment only what the code cannot say:** a non-obvious _why_, a workaround
  (name the underlying cause), an invariant, or a deliberate simplification
  (`ponytail:` marker with its limit and upgrade path). One short line where
  possible.
- **No comments that** restate the code, narrate changes or reference tickets,
  ADRs, notes or other board content — history belongs in commit messages,
  knowledge in the maintainer's knowledge base.
- **Tests document behaviour:** test names are sentences describing the
  behaviour.
- **English everywhere in the repository:** identifiers, comments, test names,
  commit messages and docs.
- **Lean means no unneeded features or abstractions — not dense code.**
- Reviewers treat violations as findings.

## Way of working (binding)

- Planning and knowledge live in the maintainer's kabai board (kabai MCP, skill
  `/kabai`); details in `CLAUDE.local.md`. The skill applies in full.
- **The `agent_role_instruction` of the column the ticket is in is your role**
  (Refine = refiner without code, In Arbeit = developer, Review = reviewer).
- Only pick up tickets from **Ready** whose `blocks` predecessors are in
  **Abnahme** (acceptance) or **done**.
- Developers move tickets at most to **Review**. A separate review agent (never
  the author) checks; findings → back to In Arbeit, otherwise "Review ok",
  merge, and on to **Abnahme**. **Only the maintainer sets done.**
- Git hygiene: no `git reset --hard`, `git clean` or `git checkout -- .`; do
  mutation probes with `git stash` or a throwaway clone.
- A decision changes? New ADR + `supersedes` link; never rewrite the old ADR.

## Stack and commands

- Quickshell 0.3 (QML) on KWin, KDE Plasma 6, Wayland; a Nix flake. Quickshell
  comes from nixpkgs, so it is built against the same Qt as Plasma; the package
  refuses any Quickshell other than 0.3.x.
- Rekta Design is a flake input pinned to one commit (source only).

```sh
nix flake check   # package, qmllint (warnings fail), token drift, QML tests, nixfmt --check
nix develop       # qs, qmllint, qmlformat, node, gitleaks, nixfmt, rekta-qmllint
nix build         # result/bin/rekta-shell, a wrapper around quickshell --path
nix fmt           # formats the Nix files
nix run .#nested -- [--outputs N] [--size WxH]   # KWin nested in the desktop, shell from the working tree, hot reload
nix run .#nested-shot -- <file.png>              # screenshot of the whole nested desktop (all outputs)
```

- `shell/Rekta/` is the QML library (module `Rekta`). `Tokens.qml` is generated from the
  pinned Rekta Design and checked in, like `IconData.js` (the icons, drawn by `Icon.qml`):
  regenerate both with `nix run .#tokens`, never edit them; the `tokens-drift` check
  fails when one differs. QML tests live in `tests/`
  (`nix build .#checks.x86_64-linux.qml-tests -L`; its result holds the contact sheets
  the tests render, e.g. `icon-sheet.png`); `generator-tests` makes sure the
  generator stops on tokens it cannot map instead of dropping them.
- `rekta-qmllint -I shell <files>` in the dev shell lints exactly like the flake check
  (Qt and Quickshell on the import path, warnings fail).
- The nested session is isolated: it starts from an empty environment (allow-list)
  with its own HOME, runtime and config directories and a session
  bus without service activation. Never pass the desktop's environment, runtime
  directory or bus into it: its plugins and config leak in, and portals or wallets
  started there break the real session's services.
- The overlay (`overlays.default`) builds `rekta-shell` against the importing
  configuration's nixpkgs.

## Git

- One branch per ticket: `ticket/<id>-<short-slug>`, branched from the current
  `main`. Small commits in English, format
  `feat|fix|chore|docs|ci: <what> (#<ticket-id>)`, one ticket per commit.
- After "Review ok" the review agent merges the ticket branch into `main` with
  `git merge --ff-only` (rebasing onto `main` first if needed) and deletes the
  branch.
- The commit identity comes from the repository configuration (noreply address)
  — never change it.
