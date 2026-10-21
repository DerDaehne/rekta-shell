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

## Licence

Code is MIT ([LICENSE](LICENSE)), documentation CC BY 4.0
([LICENSE-docs](LICENSE-docs)). Third-party material: [NOTICE](NOTICE).
