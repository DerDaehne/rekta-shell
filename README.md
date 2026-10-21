# rekta-shell

A desktop shell for KDE Plasma 6 on Wayland, built with
[Quickshell](https://quickshell.org) on KWin and designed strictly after
[Rekta Design](https://github.com/DerDaehne/rekta-design).

It runs as a session of its own, next to the regular Plasma session. KWin, the
Plasma services and KDE apps stay; plasmashell is replaced by an app bar, a
full-screen start with live tiles, a command palette, a side panel,
notifications and a lock screen in Rekta's language.

**Status:** early development. The rekta session starts, but the shell shows
no surface yet.

## Installation

On NixOS with Plasma 6, import the NixOS module and enable it. The display
manager then offers the session "rekta" beside "Plasma"; Plasma itself stays
as it is.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rekta-shell = {
      url = "github:DerDaehne/rekta-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rekta-shell, ... }:
    {
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          rekta-shell.nixosModules.default
          {
            services.desktopManager.plasma6.enable = true;
            programs.rekta-shell.enable = true;
          }
        ];
      };
    };
}
```

The module builds the shell with your system's nixpkgs, so Quickshell shares
Qt with your Plasma. `homeManagerModules.default` offers the same
`programs.rekta-shell.enable` per user; it puts the `rekta-shell` command into
the user's profile and will carry per-user settings. Every option of both
modules is off by default: importing them changes nothing until a
configuration enables them.

Without the modules, the flake provides `packages.<system>.rekta-shell` and
`overlays.default`. The package carries the session as well: register it with
`services.displayManager.sessionPackages` and `systemd.packages`. Use the
overlay, or set `inputs.rekta-shell.inputs.nixpkgs.follows = "nixpkgs"`, so the
shell is built against your own nixpkgs; `packages.<system>` alone uses this
flake's own nixpkgs pin.

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
