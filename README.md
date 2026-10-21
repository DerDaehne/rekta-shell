# rekta-shell

A desktop shell for KDE Plasma 6 on Wayland, built with
[Quickshell](https://quickshell.org) on KWin and designed strictly after
[Rekta Design](https://github.com/DerDaehne/rekta-design).

It runs as a session of its own, next to the regular Plasma session. KWin, the
Plasma services and KDE apps stay; plasmashell is replaced by an app bar, a
full-screen start with live tiles, a command palette, a side panel,
notifications and a lock screen in Rekta's language.

**Status:** early development — nothing to install yet.

## Installation

Planned: a Nix flake with a NixOS module and a home-manager module. Every
option is off by default, so importing the flake changes nothing until a
configuration enables it.

## Contributing

This repository is public, so nothing private may enter it. Before every commit
run `scripts/scan-secrets.sh`: gitleaks over the history and the pending
changes, built-in checks (board references, English comments, no local home
paths, noreply commit identities) and a scan against your own private patterns.

Put those patterns into `.privacy-patterns` in the repository root — one
`grep -E` regex per line, for example your real name, private mail addresses,
host and device names. The file is gitignored; `.privacy-patterns.example`
shows the format. A hit names only the file, line or commit and a pattern
number, never the pattern itself. `scripts/scan-secrets.test.sh` tests the
scan.

## Licence

Code is MIT ([LICENSE](LICENSE)), documentation CC BY 4.0
([LICENSE-docs](LICENSE-docs)). Third-party material: [NOTICE](NOTICE).
