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
  The one exception is what Rekta itself keeps as literals in its stylesheet (fixed
  geometry such as hairlines and the focus ring; the loading line's and the dots'
  motion until it has tokens): it lives only in `shell/Rekta/Geometry.qml`, each
  value naming its rule in Rekta's stylesheet.
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
- Agents never open a window on the maintainer's desktop: the nested session
  and the VM run headless by default. `--window` only when the maintainer asks
  to watch.
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
nix flake check   # package, qmllint (warnings fail), token drift, QML tests, modules, nixfmt --check
nix develop       # qs, qmllint, qmlformat, node, gitleaks, nixfmt, rekta-qmllint
nix build         # result/bin/rekta-shell, a wrapper around quickshell --path
nix fmt           # formats the Nix files
nix run .#nested -- [--window] [--outputs N] [--size WxH] [--background rekta|solid]   # own KWin, hot reload
nix run .#nested-shot -- <file.png>                         # screenshot of the whole nested desktop (all outputs)
nix run .#vm -- [--window] [QEMU args]                      # throwaway NixOS VM with Plasma 6, started from the checkout root
```

- Both run headless by default: the nested KWin renders into a virtual
  framebuffer (`kwin_wayland --virtual`) and never gets the desktop's display,
  the VM runs with `-display none`. Look at them with `nested-shot` or the
  monitor's `screendump`. `--window` restores the window in the desktop (a
  nested KWin window, QEMU's GTK window), which takes focus.
- `shell/Rekta/` is the QML library (module `Rekta`). `Tokens.qml` is generated from the
  pinned Rekta Design and checked in, like `IconData.js` (the icons, drawn by `Icon.qml`):
  regenerate both with `nix run .#tokens`, never edit them; the `tokens-drift` check
  fails when one differs. QML tests live in `tests/`
  (`nix build .#checks.x86_64-linux.qml-tests -L`; its result holds the contact sheets
  the tests render, e.g. `icon-sheet.png`); `generator-tests` makes sure the
  generator stops on tokens it cannot map instead of dropping them.
- `rekta-qmllint -I shell <files>` in the dev shell lints exactly like the flake check
  (Qt, Quickshell and plasma-workspace on the import path, warnings fail).
- `session/` holds the rekta session's files: its desktop entry, the start script
  (`XDG_SESSION_DESKTOP=rekta`, `PLASMA_DEFAULT_SHELL`, then `startplasma-wayland`),
  `rekta-shell.service` and the drop-ins that skip plasmashell and pull the shell into
  `plasma-workspace.target`. A drop-in on `plasma-kwin_wayland.service` runs Plasma's
  KWin command through `libexec/rekta-kwin`, which only in the rekta session puts the
  `rekta-kwin` package (`kwin/`: effects, kwinrc defaults), the Rekta module and the
  `org.kde.desktop` controls style into KWin's environment; the
  `kwin-drop-in-follows-plasma` check fails once Plasma's command changes. The package
  installs them with their store paths filled in (`share/wayland-sessions`, `libexec`,
  `lib/systemd/user`).
- `nixosModules.default` (`nix/nixos-module.nix`) registers that package as session
  and systemd package once `programs.rekta-shell.enable` is set;
  `homeManagerModules.default` (`nix/home-module.nix`) is the per-user counterpart.
  Both build the package with the importing configuration's pkgs. The `nixos-module`
  and `home-module` checks evaluate them: with defaults a system's `toplevel` stays
  the same, enabled the session is registered. New options default to off.
- The nested session is isolated: it starts from an empty environment (allow-list)
  with its own HOME, runtime and config directories and a session
  bus without service activation. Never pass the desktop's environment, runtime
  directory or bus into it: its plugins and config leak in, and portals or wallets
  started there break the real session's services.
- `nix run .#vm` is for what a nested session cannot show: session start,
  systemd, the lock screen and global shortcuts. It logs in automatically as the
  test user `rekta` (public test password `rekta`) and mounts the checkout's
  `shell/` read-only at `/mnt/rekta-shell/shell`, so `qs --path
  /mnt/rekta-shell/shell` runs the working tree. The disk image lives in a
  temporary directory that is deleted when the VM exits (monitor `quit`, Ctrl+C,
  SIGTERM to the app, or the closed `--window`); the VM is never built by `nix
  flake check`. There is no GL: Plasma renders in software. Arguments after `--`
  go to QEMU, after an optional leading `--window`; host variables such as
  `QEMU_OPTS` or `SHARED_DIR` are ignored. The test user may `sudo` with its
  password.
- The VM's SDDM offers "Plasma (Wayland)" and "rekta", the session from the
  NixOS module (`programs.rekta-shell.enable`): Plasma's services without
  plasmashell, `rekta-shell.service` in its
  place, with the shell as the VM was built (not the mounted working tree).
  Autologin starts Plasma.
  To switch, log out (`busctl --user call org.kde.Shutdown /Shutdown
  org.kde.Shutdown logout`) and pick the session in the greeter: Tab runs
  Sleep, Restart, Shut Down, Other…, Virtual Keyboard, Desktop Session, user,
  password; Space opens the session list, Down and Return choose. The greeter
  hides its controls after a few seconds without input, and a key pressed then
  may only bring them back: wake it with `sendkey shift` and check the focus
  with a `screendump`.
- Driving the VM from a script: the guest's serial console (a login shell) and
  the QEMU monitor (screenshots, keys) as FIFOs; this works headless.
  `sendkey` is also the reliable way to press Meta in a `--window` VM: the GTK
  window only grabs the keyboard after Ctrl+Alt+G, before that the desktop's
  KWin takes Meta.

  ```sh
  d=$(mktemp -d); mkfifo "$d"/{ser,mon}.{in,out}
  cat "$d/ser.out" > "$d/ser.log" & cat "$d/mon.out" > "$d/mon.log" &
  nix run .#vm -- -serial pipe:"$d/ser" -monitor pipe:"$d/mon" &
  wait_for() { timeout 300 sh -c 'until grep -aq "$1" "$2"; do sleep 1; done' _ "$1" "$d/ser.log"; }
  wait_for 'login:' && printf 'rekta\r' > "$d/ser.in"
  wait_for 'Password:' && printf 'rekta\r' > "$d/ser.in"
  wait_for 'rekta@nixos'                                          # a shell on ttyS0
  printf 'export PAGER=cat SYSTEMD_PAGER=cat\r' > "$d/ser.in"     # a pager would swallow the next commands
  printf 'systemctl --user show-environment\r' > "$d/ser.in"     # output lands in ser.log
  printf 'screendump %s -f png\n' "$d/shot.png" > "$d/mon.in"     # screenshot from the host
  printf 'sendkey meta_l\n' > "$d/mon.in"                         # Meta into the guest
  printf 'quit\n' > "$d/mon.in"; wait; rm -rf "$d"                # stop the VM, remove the FIFOs
  ```

  Plasma is up about half a minute after the login prompt; screenshots and keys
  sent earlier hit the boot screen.

  In the guest the session's Wayland socket is `wayland-1`, not `wayland-0`:
  take the session's variables from `systemctl --user show-environment`, or
  start programs in it with `systemd-run --user`.

  The VM has no sound card unless QEMU gets one: `-audiodev none,id=snd0
  -device intel-hda -device hda-duplex,audiodev=snd0` after `--` gives PipeWire
  a sink and a source. `sendkey` knows the volume and media keys (`volumeup`,
  `audiomute`, `audioplay`, …) but not mic mute or brightness; write those to a
  uinput device in the guest as root (the guest mounts the host's `/nix/store`,
  so a tool built on the host, such as python-evdev, runs there).
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
