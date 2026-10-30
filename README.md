# rekta-shell

A desktop shell for KDE Plasma 6 on Wayland, built with
[Quickshell](https://quickshell.org) on KWin and designed strictly after
[Rekta Design](https://github.com/DerDaehne/rekta-design).

It runs as a session of its own, next to the regular Plasma session. KWin, the
Plasma services and KDE apps stay; plasmashell is replaced by an app bar, a
full-screen start with live tiles, a command palette, a side panel,
notifications and a lock screen in Rekta's language.

**Status:** early beta. The session has the app bar with clock and calendar,
the background, notifications, background apps ("im hintergrund") and the
Start on Meta. Still missing: the command palette, the side panel, the volume
display, the clipboard history and Rekta's own lock screen.

## Installation on NixOS

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

`programs.rekta-shell.background` picks the background: `"rekta"` (the
default, Rekta's tile echo) or `"solid"` (the plain ground colour).

The module's options are the shell's defaults. Each user can set their own in
`~/.config/rekta-shell/settings.json`, which wins over them and takes effect
while the shell runs, for example `{ "version": 1, "background": "solid" }`.
The shell only reads that file; nothing in the Nix configuration writes it.

## Using rekta as a second session on NixOS

- **Switch sessions:** log out and pick "rekta" in the display manager's
  session list; to go back, log out and pick "Plasma". The display manager
  preselects the last session, so after a failed rekta login pick Plasma
  explicitly.
- **Update:** run `nix flake update rekta-shell` in your configuration, then
  build and switch as usual. The new shell starts with the next rekta login;
  inside a running rekta session, `systemctl --user restart rekta-shell` picks
  it up at once.
- **Go back to an earlier version:** revert the `flake.lock` change and switch
  again, or `nixos-rebuild switch --rollback`, or boot an earlier generation.
- **What both sessions share:** KDE's settings (`kwinrc`, `kdeglobals`,
  shortcuts) and the session restore, so windows open at logout reopen in the
  other session. The rekta session adds its own KWin defaults (its desktop
  switch, blur strength, no open animation) through a drop-in that only acts
  in rekta; your own `kwinrc` settings win over them.
- **When the shell misbehaves:** `systemctl --user status rekta-shell` and
  `journalctl --user -u rekta-shell -b`; KWin logs with
  `journalctl --user -u plasma-kwin_wayland -b`. The shell restarts after
  every exit, at most three times a minute; after that the unit stays failed
  and the session runs on without it. Bring it back with
  `systemctl --user reset-failed rekta-shell && systemctl --user start rekta-shell`.
- **When the session does not come up at all:** switch to a text console
  (Ctrl+Alt+F3), log in, end the session with `loginctl terminate-session <id>`
  (see `loginctl list-sessions`) and pick Plasma in the display manager. Last
  resort: set `programs.rekta-shell.enable = false;` and switch, or roll back.

## Installation on Fedora

Fedora is supported as an x86_64 RPM. Requirements: a Fedora release that ships
Plasma 6.8 or newer, and Quickshell 0.3, which Fedora does not package yet.

1. Enable the Quickshell repository first. It is a third-party COPR and not part
   of this project:

   ```sh
   sudo dnf copr enable errornointernet/quickshell
   ```

2. Plasma 6.8 is in Fedora 45's `updates-testing` repository for now. Until it
   is stable, enable that repository once to bring Plasma up to 6.8 (this step
   goes away when Fedora ships Plasma 6.8 as a stable update):

   ```sh
   sudo dnf --enablerepo=updates-testing upgrade
   ```

3. Download the RPM for your Fedora release and `SHA256SUMS` from the
   [GitHub release](https://github.com/DerDaehne/rekta-shell/releases) of the
   version you want (the file name carries the release, for example `fc45`),
   then check it and install it:

   ```sh
   sha256sum -c --ignore-missing SHA256SUMS
   sudo dnf install ./rekta-shell-<version>.fc45.x86_64.rpm
   ```

   To try the state of `main` before a release, download the workflow artifact
   instead (it expires after 30 days):

   ```sh
   gh run download <run-id> -n rekta-shell-<version>-fc45-<sha7>
   ```

   The RPM is not signed, so `dnf` does not verify it; the checksum is the check.

4. Log out and pick "rekta" in the login manager's session list: the gear icon
   in GDM, the session selector in the Plasma Login Manager or SDDM. To go back,
   log out and pick "Plasma". The login manager preselects the last session, so
   after a failed rekta login pick Plasma explicitly.

The package depends on KWin `>= 6.8, < 6.9` because the shell's KWin effect uses
KWin's internal headers, which change with every Plasma minor release. When
Plasma 6.9 arrives, `dnf` holds the Plasma packages back until a new rekta-shell
RPM for it is installed.

### Defaults, update, removal

- **Defaults:** `/etc/rekta-shell/defaults.json` holds the system-wide defaults.
  It is a JSON object with the keys `background` (`"rekta"` or `"solid"`) and
  `density`, and ships as `{ "background": "rekta" }`. A user's own
  `~/.config/rekta-shell/settings.json` wins over it. The shell reads the
  defaults at start, so a change takes effect after
  `systemctl --user restart rekta-shell` or the next login. A changed file is
  kept on updates (the new one arrives as `defaults.json.rpmnew`) and on
  removal (as `defaults.json.rpmsave`).
- **Update:** install the newer RPM the same way as above. `dnf upgrade` does
  not find a new rekta-shell by itself, since a release RPM brings no
  repository. The new shell starts with the next rekta login; inside a running
  rekta session, `systemctl --user restart rekta-shell` picks it up at once.
- **Remove:** `sudo dnf remove rekta-shell`. `dnf` also offers to remove
  packages that only rekta-shell pulled in, which on a system without Plasma
  includes Plasma itself; read the list before confirming. Your home directory
  is not touched.
- **Troubleshooting and the way back:** `systemctl --user status rekta-shell`
  and `journalctl --user -u rekta-shell -b` show what the shell does; the
  notes in "Using rekta as a second session on NixOS" about restarts apply
  unchanged. If the session does not come up at all, switch to a text console
  (Ctrl+Alt+F3), log in, end the session with `loginctl terminate-session <id>`
  (see `loginctl list-sessions`) and pick Plasma. Last resort:
  `sudo dnf remove rekta-shell`.

### Next to GNOME

rekta also runs on a Fedora Workstation with GNOME, next to it. The RPM then
pulls in the Plasma services the session needs (about 750 MiB on disk), and
`plasma-nm` and `bluedevil` as weak dependencies; they answer network passwords
and Bluetooth pairing in the rekta session, and `--setopt=install_weak_deps=False`
leaves them out. GNOME itself stays unchanged. What you notice when you switch:

- **Two password stores:** the rekta session uses KWallet, GNOME uses
  gnome-keyring. Passwords saved in one are not visible in the other.
- **Portals:** GNOME uses the GNOME portals, rekta the KDE ones, so file dialogs
  look different in each session.
- **Application lists:** rekta lists GNOME's apps as well. KDE apps that are
  marked KDE-only do not show up in GNOME. The Plasma welcome centre starts the
  first time you log in to rekta.
- **Network and Bluetooth:** NetworkManager and BlueZ are the same services in
  both sessions; only the agent that asks for passwords and pairing differs.
- **`xwaylandvideobridge` starts in GNOME:** a weak dependency of Plasma that
  autostarts in every desktop. It is invisible, and rekta does not need it:
  `sudo dnf remove xwaylandvideobridge`.
- **Leftovers:** the first session you start writes configuration (`kdeglobals`,
  `kwinrc` and more in `~/.config`) that the other session ignores.

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
