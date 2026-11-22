{ pkgs, self }:

let
  rekta-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell-unversioned;
  # The package users get: the same build with the commit behind its version.
  versioned = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell;
  rekta-qmllint = pkgs.callPackage ./qmllint.nix { inherit rekta-shell; };
  # The tests import the shell's directories by relative path, so both stand side by side here.
  qml = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../shell
      ../settings
      ../lockscreen
      ../tests
    ];
  };
  dist = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-design-dist;
  qt = pkgs.kdePackages;
  inherit (pkgs) lib;
  # The unit and drop-ins of the rekta session, relative to a user-unit directory.
  userUnits = [
    "rekta-shell.service"
    "plasma-kwin_wayland.service.d/rekta-session.conf"
    "plasma-kded6.service.d/rekta-session.conf"
    "plasma-plasmashell.service.d/rekta-session.conf"
    "plasma-workspace.target.d/rekta-shell.conf"
  ];
  # The removed start tempo, once set, fails an assertion that says why.
  removedOptionStops =
    assertions:
    lib.any (
      a:
      !a.assertion
      && lib.hasInfix "The Start always turns at Rekta's pace for a called place; there is no setting." a.message
    ) assertions;

  # The home-manager module evaluated with stand-ins for home.packages, fonts.fontconfig.enable and assertions, so the checks need no home-manager input.
  homeConfig =
    modules:
    (lib.evalModules {
      modules = [
        {
          options.fonts.fontconfig.enable = lib.mkEnableOption "fontconfig";
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.unspecified;
            default = [ ];
          };
          options.home.packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
        }
        { _module.args.pkgs = pkgs; }
        self.homeManagerModules.default
      ]
      ++ modules;
    }).config;
in
{
  package = rekta-shell;

  # Quickshell loads the DBus module into its own process; a Quickshell linking another Qt must stop the build.
  package-refuses-foreign-qt =
    let
      foreignQuickshell = rekta-shell.quickshell.overrideAttrs { buildInputs = [ ]; };
      foreign = rekta-shell.override { quickshell = foreignQuickshell; };
    in
    assert lib.assertMsg (
      !(builtins.tryEval foreign.drvPath).success
    ) "rekta-shell builds with a Quickshell that links another Qt";
    pkgs.runCommand "rekta-shell-package-refuses-foreign-qt" { } "touch $out";

  # A system or home profile links share/ and etc/xdg of its packages into every session's XDG dirs and lib/qt-6/plugins
  # into its plugin path, Plasma's too: the package may bring no KWin effects, config defaults, plugins or shell
  # packages (a lock screen) there. Its DBus module is a QML module in the namespace RektaShell, which nothing of Plasma
  # imports, so lib/qt-6/qml may hold that alone.
  profile-leaves-plasma-alone =
    let
      profile = pkgs.buildEnv {
        name = "rekta-shell-profile";
        paths = [ rekta-shell ];
      };
    in
    pkgs.runCommand "rekta-shell-profile-leaves-plasma-alone" { } ''
      for path in share/kwin share/plasma etc/xdg lib/qt-6/plugins; do
        if [ -e ${profile}/$path ]; then
          echo "a profile with the rekta package puts $path into every session" >&2
          exit 1
        fi
      done
      other=$(ls ${profile}/lib/qt-6/qml | grep -vx RektaShell || true)
      if [ -n "$other" ]; then
        echo "a profile with the rekta package puts $other into every session's QML imports" >&2
        exit 1
      fi
      touch $out
    '';

  # The session files are templates; one that keeps a placeholder or an empty value would only fail in a session.
  session-files-are-filled = pkgs.runCommand "rekta-shell-session-files-are-filled" { } ''
    cd ${rekta-shell}
    if grep -rIE '@[A-Za-z_]+@' bin libexec share/systemd share/wayland-sessions; then
      echo "a placeholder is left in the package" >&2
      exit 1
    fi
    grep -qF 'QT_PLUGIN_PATH="${rekta-shell}/lib/rekta-kwin/plugins' libexec/rekta-kwin
    grep -qF 'XDG_DATA_DIRS="${rekta-shell}/share/rekta-kwin:' libexec/rekta-kwin
    grep -qF 'XDG_CONFIG_DIRS="${rekta-shell}/share/rekta-kwin/kwin:' libexec/rekta-kwin
    grep -qF 'XDG_CONFIG_DIRS="${rekta-shell}/share/rekta-kded:' libexec/rekta-kded
    # rekta-kwin puts this directory on the import path of the greeter, whose lock screen asks the shell through it.
    test -f lib/qt-6/qml/RektaShell/DBus/qmldir
    grep -qx '\[Module-mprisservice\]\[$i\]' share/rekta-kded/kded5rc
    # The greeter KWin starts finds the lock screen's package by this name, under KWin's data dirs alone.
    grep -qx '  export PLASMA_DEFAULT_SHELL=rekta-lockscreen' libexec/rekta-kwin
    grep -qF '"Id": "rekta-lockscreen"' share/rekta-kwin/plasma/shells/rekta-lockscreen/metadata.json
    test -f share/rekta-kwin/plasma/shells/rekta-lockscreen/contents/lockscreen/LockScreen.qml
    if grep -q PLASMA_DEFAULT_SHELL libexec/rekta-session; then
      echo "the start script hands the lock screen's package to the user manager, where the logout greeter misses it" >&2
      exit 1
    fi
    touch $out
  '';

  # NixOS collects user units from systemd.packages only under etc/systemd/user and lib/systemd/user, so the package
  # installs them there (the nixos-module check proves they reach an enabled system's /etc/systemd/user).
  user-units-are-where-nixos-looks =
    pkgs.runCommand "rekta-shell-user-units-are-where-nixos-looks" { }
      ''
        for unit in ${lib.escapeShellArgs userUnits}; do
          test -f ${rekta-shell}/lib/systemd/user/$unit || { echo "lib/systemd/user has no $unit" >&2; exit 1; }
        done
        touch $out
      '';

  # The settings app is found by its desktop entry in every session, so the entry and the wrapper must be there, and the
  # entry must not hide itself from Plasma.
  settings-app =
    pkgs.runCommand "rekta-shell-settings-app" { nativeBuildInputs = [ pkgs.desktop-file-utils ]; }
      ''
        desktop=${rekta-shell}/share/applications/rekta-settings.desktop
        desktop-file-validate $desktop
        grep -qx "Exec=rekta-settings" $desktop
        if grep -qE "^(OnlyShowIn|NotShowIn|NoDisplay|Hidden)=" $desktop; then
          echo "the settings entry hides itself in some session" >&2
          exit 1
        fi
        test -x ${rekta-shell}/bin/rekta-settings
        grep -qF "${rekta-shell.quickshell}/bin" ${rekta-shell}/bin/.rekta-settings-wrapped
        grep -qF "${rekta-shell}/share/rekta-settings" ${rekta-shell}/bin/.rekta-settings-wrapped
        grep -qx "//@ pragma AppId rekta-settings" ${rekta-shell}/share/rekta-settings/shell.qml
        grep -q "no-duplicate" ${rekta-shell}/bin/.rekta-settings-wrapped
        touch $out
      '';

  # The rekta drop-in replaces KWin's command in both sessions, so a Plasma update that changes the command must fail here.
  kwin-drop-in-follows-plasma = pkgs.runCommand "rekta-shell-kwin-drop-in-follows-plasma" { } ''
    plasma=$(sed -n 's/^ExecStart=//p' ${qt.kwin}/share/systemd/user/plasma-kwin_wayland.service)
    rekta=$(sed -n 's|^ExecStart=${rekta-shell}/libexec/rekta-kwin ||p' \
      ${rekta-shell}/share/systemd/user/plasma-kwin_wayland.service.d/rekta-session.conf)
    if [ "$rekta" != "$plasma" ]; then
      echo "the rekta drop-in runs '$rekta' through rekta-kwin, plasma-kwin_wayland.service runs '$plasma'" >&2
      exit 1
    fi
    touch $out
  '';

  # The same for kded6: its drop-in replaces kded6's command in both sessions.
  kded-drop-in-follows-plasma = pkgs.runCommand "rekta-shell-kded-drop-in-follows-plasma" { } ''
    plasma=$(sed -n 's/^ExecStart=//p' ${qt.kded}/share/systemd/user/plasma-kded6.service)
    rekta=$(sed -n 's|^ExecStart=${rekta-shell}/libexec/rekta-kded ||p' \
      ${rekta-shell}/share/systemd/user/plasma-kded6.service.d/rekta-session.conf)
    if [ "$rekta" != "$plasma" ]; then
      echo "the rekta drop-in runs '$rekta' through rekta-kded, plasma-kded6.service runs '$plasma'" >&2
      exit 1
    fi
    touch $out
  '';

  # The spellings of "dock" that tell the fade-back the shell's surfaces apart (the Start's "dOck", the session bar's
  # "DOCK", the key map's "Dock" and others) are docks only while KWin ignores the case as it types a layer surface; else
  # KWin takes them for normal windows.
  kwin-types-docks-ignoring-case = pkgs.runCommand "rekta-shell-kwin-types-docks-ignoring-case" { } ''
    # Read to a file: `grep -q` ending a pipeline early would hand tar a SIGPIPE, which pipefail reports as a miss.
    tar -xOf ${qt.kwin.src} --wildcards '*/src/layershellv1window.cpp' > layershellv1window.cpp
    if ! grep -qF 'scopeToType.value(scope.toLower(),' layershellv1window.cpp; then
      echo "KWin no longer types a layer surface by its lowercased namespace; the shell's spellings of \"dock\" need other tags" >&2
      exit 1
    fi
    touch $out
  '';

  # Both drop-ins run Plasma's commands through their scripts in Plasma too, so only in the rekta session may a script
  # change what the command gets. A child stands in for the command: it sees the same, run through a script with one
  # environment, as run directly with the environment the script must hand on.
  drop-ins-change-only-rekta =
    let
      child = pkgs.writeShellScript "child" ''
        printf 'argument %s\n' "$@"
        # Each shell counts it up, so it tells only how many shells ran before.
        unset SHLVL
        ${pkgs.coreutils}/bin/env | ${pkgs.coreutils}/bin/sort
      '';
    in
    pkgs.runCommand "rekta-shell-drop-ins-change-only-rekta" { } ''
      expect() {
        local script=$1 given=$2 handed=$3
        if ! diff <(env -i $handed ${child} 'two words' --flag) \
          <(env -i $given ${rekta-shell}/libexec/$script ${child} 'two words' --flag) >&2; then
          echo "$script turns '$given' into more or less than '$handed'" >&2
          exit 1
        fi
      }
      session="XDG_CONFIG_DIRS=/session/xdg XDG_DATA_DIRS=/session/share QT_PLUGIN_PATH=/session/plugins QML_IMPORT_PATH=/session/qml"
      for script in rekta-kwin rekta-kded; do
        for desktop in XDG_SESSION_DESKTOP=KDE XDG_SESSION_DESKTOP= ""; do
          expect $script "$desktop $session" "$desktop $session"
          expect $script "$desktop" "$desktop"
        done
      done

      # env keeps the last value given for a name, so an expectation names only what the script changes.
      rekta=XDG_SESSION_DESKTOP=rekta
      kded=${rekta-shell}/share/rekta-kded
      expect rekta-kded "$rekta $session" "$rekta $session XDG_CONFIG_DIRS=$kded:/session/xdg"
      expect rekta-kded "$rekta" "$rekta XDG_CONFIG_DIRS=$kded:/etc/xdg"
      kwin=${rekta-shell}/share/rekta-kwin
      plugins=${rekta-shell}/lib/rekta-kwin/plugins
      module=${rekta-shell}/share/rekta-shell:${rekta-shell}/lib/qt-6/qml
      style="QT_QUICK_CONTROLS_STYLE=org.kde.desktop PLASMA_DEFAULT_SHELL=rekta-lockscreen"
      expect rekta-kwin "$rekta $session" "$rekta $session XDG_CONFIG_DIRS=$kwin/kwin:/session/xdg \
        XDG_DATA_DIRS=$kwin:/session/share QT_PLUGIN_PATH=$plugins:/session/plugins QML_IMPORT_PATH=$module:/session/qml $style"
      expect rekta-kwin "$rekta" "$rekta XDG_CONFIG_DIRS=$kwin/kwin:/etc/xdg XDG_DATA_DIRS=$kwin:/usr/local/share:/usr/share \
        QT_PLUGIN_PATH=$plugins QML_IMPORT_PATH=$module $style"
      touch $out
    '';

  # KWin makes a layer surface of a namespace it does not know, or of none, a normal window: tiling scripts place it as
  # they place an app's, out of any zone it keeps clear for itself, and glide, fade and scale animate it. Of the types
  # KWin knows, only a dock is left alone by its own effects, so every surface of the shell is one.
  shell-surfaces-are-docks = pkgs.runCommand "rekta-shell-shell-surfaces-are-docks" { } ''
    if grep -rnE --include='*.qml' 'WlrLayershell.namespace:' ${../shell} | grep -viE 'WlrLayershell.namespace: "dock"$' >&2; then
      echo "a surface of the shell is no dock to KWin" >&2
      exit 1
    fi
    # One namespace per surface in each file: a second surface in a file that names one would go without.
    if ! find ${../shell} -name '*.qml' -exec awk '
      { surfaces[FILENAME] += gsub(/PanelWindow[[:space:]]*\{/, "&") }
      /WlrLayershell\.namespace:/ { names[FILENAME]++ }
      END {
        for (file in surfaces)
          if (surfaces[file] != names[file]) {
            print file " has " surfaces[file] " surfaces but " names[file] + 0 " namespaces"
            failed = 1
          }
        exit failed
      }' {} + >&2; then
      echo "a surface of the shell names no namespace, so it is no dock to KWin" >&2
      exit 1
    fi
    touch $out
  '';

  # No unit test can load a surface: each blur goes through BlurRegion, which takes it away under less transparency.
  blur-goes-through-blur-region = pkgs.runCommand "rekta-shell-blur-goes-through-blur-region" { } ''
    if grep -rn --include='*.qml' blurRegion ${../shell} ${../settings} ${../lockscreen} |
      grep -v 'BackgroundEffect.blurRegion: BlurRegion {$'; then
      echo "a surface blurs past BlurRegion, so less transparency would keep its blur" >&2
      exit 1
    fi
    touch $out
  '';

  # Lint and tests stay green with a forgotten debug line; only `info`, `warn` and `error` are meant to reach the journal.
  no-debug-logging = pkgs.runCommand "rekta-shell-no-debug-logging" { } ''
    if grep -rnE --include='*.qml' --include='*.js' \
      '\bconsole\.(log|debug|trace|dir|dirxml|table|time[A-Za-z]*|count[A-Za-z]*|assert)\b|(^|[^.A-Za-z0-9_])print\(' \
      ${../shell} ${../settings} ${../lockscreen}; then
      echo "debug output left in the code: use console.info, console.warn or console.error for output that is meant to stay" >&2
      exit 1
    fi
    touch $out
  '';

  # Window-level behaviour no unit test can instantiate: the open Start lies over the bar without moving it, and
  # a toast keeps its own surface on the overlay layer above the Start.
  start-covers-the-bar = pkgs.runCommand "rekta-shell-start-covers-the-bar" { } ''
    if grep 'readonly property bool away:' ${../shell/Bar.qml} | grep startOpen >/dev/null; then
      echo "Bar.away must not depend on the open Start" >&2
      exit 1
    fi
    grep -q 'WlrLayershell.layer: stepsBack ? WlrLayer.Top : WlrLayer.Overlay' ${../shell/Toasts.qml}
    grep -q 'value: panel.floatOpen && !panel.startOpen' ${../shell/Bar.qml}
    touch $out
  '';

  # The bar's window no unit test can instantiate either: a toast counts "meldungen" in sight only once it shows, not
  # while it waits, back from "mehr", for the others to make room (tst_appbar.qml holds what `showing` means).
  count-in-sight = pkgs.runCommand "rekta-shell-count-in-sight" { } ''
    if ! grep -qF 'value: !panel.away && bell.showing' ${../shell/Bar.qml}; then
      echo "Bar.qml: the toaster's countInSight must follow bell.showing, so a held \"meldungen\" is not in sight" >&2
      exit 1
    fi
    touch $out
  '';

  qmllint = pkgs.runCommand "rekta-shell-qmllint" { LANG = "C.UTF-8"; } ''
    find ${qml} -name '*.qml' -print0 | xargs -0 ${pkgs.lib.getExe rekta-qmllint} -I ${qml}/shell
    touch $out
  '';

  # qmllint's JSON report carries the "Did you mean" lines and messages without a line; rekta-qmllint must print both.
  qmllint-report = pkgs.runCommand "rekta-shell-qmllint-report" { LANG = "C.UTF-8"; } ''
    lint=${pkgs.lib.getExe rekta-qmllint}
    # Runs the wrapper with stderr in $1.log and fails unless it exits with $2.
    expect_status() {
      local log=$1 want=$2 got=0
      shift 2
      "$lint" "$@" > "$log.out" 2> "$log.log" || got=$?
      [ "$got" = "$want" ] || { cat "$log.log"; echo "$*: exit $got, expected $want" >&2; exit 1; }
    }
    cat > typo.qml <<'QML'
    import QtQuick
    Item {
        property int fooBar: 1
        Component.onCompleted: console.log(fooBarr)
    }
    QML
    cat > clean.qml <<'QML'
    import QtQuick
    Item {}
    QML
    expect_status typo 255 typo.qml
    grep -qF 'Did you mean "fooBar"?' typo.log || { cat typo.log; echo "suggestion missing" >&2; exit 1; }
    expect_status missing 255 missing.qml
    grep -q '^missing.qml: warning: Failed to open' missing.log || { cat missing.log; echo "location-less message wrong" >&2; exit 1; }
    expect_status clean 0 clean.qml
    expect_status help 0 --help
    grep -q '^Usage: qmllint' help.out
    expect_status version 0 --version
    grep -q 'qmllint' version.out
    touch $out
  '';

  tokens-drift =
    pkgs.runCommand "rekta-shell-tokens-drift" { nativeBuildInputs = [ pkgs.nodejs ]; }
      ''
        node ${../scripts/generate-tokens.mjs} ${dist} ${../shell} --check
        touch $out
      '';

  generator-tests =
    pkgs.runCommand "rekta-shell-generator-tests" { nativeBuildInputs = [ pkgs.nodejs ]; }
      ''
        export HOME="$TMPDIR"
        REKTA_DESIGN_DIST=${dist} node --test ${../scripts}/generate-tokens.test.mjs
        touch $out
      '';

  qml-tests = pkgs.callPackage ./qml-tests.nix { inherit rekta-shell qml; };

  start-file =
    pkgs.runCommand "rekta-shell-start-file"
      {
        nativeBuildInputs = [
          rekta-shell.quickshell
          pkgs.dbus
          pkgs.diffutils
        ];
        QML_IMPORT_PATH = "${qml}/shell";
      }
      ''
        dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- sh ${qml}/tests/startfile.sh
        touch $out
      '';

  nixos-module =
    let
      system =
        modules:
        (self.inputs.nixpkgs.lib.nixosSystem {
          modules = [
            {
              nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
              boot.isContainer = true;
              system.stateVersion = "26.11";
            }
          ]
          ++ modules;
        }).config;
      toplevel = modules: (system modules).system.build.toplevel.drvPath;
      # The kind of system the module is imported into, so the comparison sees what it could change there:
      # the display manager's sessions, user units and Plasma's own packages.
      plasma = {
        services.desktopManager.plasma6.enable = true;
        services.displayManager.sddm.enable = true;
      };
      module = self.nixosModules.default;
      enable = {
        programs.rekta-shell.enable = true;
      };
      enabled = system [
        plasma
        module
        enable
      ];
      withBackground =
        background:
        system [
          plasma
          module
          enable
          { programs.rekta-shell.background = background; }
        ];
      withDensity =
        density:
        system [
          plasma
          module
          enable
          { programs.rekta-shell.density = density; }
        ];
      withSettings =
        settings:
        system [
          plasma
          module
          enable
          { programs.rekta-shell = settings; }
        ];
      withoutPlasma = system [
        module
        enable
      ];
    in
    assert lib.assertMsg (
      toplevel [ plasma ] == toplevel [
        plasma
        module
      ]
    ) "importing the NixOS module with its defaults changed the system";
    assert lib.assertMsg (
      toplevel [ plasma ] == toplevel [
        plasma
        module
        { programs.rekta-shell.background = "rekta"; }
      ]
    ) "the background option changed a system that does not enable the module";
    assert lib.assertMsg (
      toplevel [ plasma ] == toplevel [
        plasma
        module
        { programs.rekta-shell.density = "comfortable"; }
      ]
    ) "the density option changed a system that does not enable the module";
    assert lib.assertMsg (
      toplevel [ plasma ] == toplevel [
        plasma
        module
        {
          programs.rekta-shell = {
            searchEscape = "back";
            showRecent = false;
            contrast = "more";
            transparency = "reduce";
          };
        }
      ]
    ) "the Start, contrast or transparency options changed a system that does not enable the module";
    assert lib.assertMsg (
      toplevel [ plasma ] == toplevel [
        plasma
        module
        { programs.rekta-shell.installFont = false; }
      ]
    ) "the installFont option changed a system that does not enable the module";
    assert lib.assertMsg (removedOptionStops
      (withSettings { startTempo = "rekta"; }).assertions
    ) "a start tempo set in the NixOS module does not stop the build with the reason";
    assert lib.assertMsg (lib.elem pkgs.atkinson-hyperlegible-next enabled.fonts.packages)
      "the enabled NixOS module does not install the typeface";
    assert lib.assertMsg (
      !lib.elem pkgs.atkinson-hyperlegible-next (withSettings { installFont = false; }).fonts.packages
    ) "installFont = false still installs the typeface";
    assert lib.assertMsg (lib.elem "rekta" enabled.services.displayManager.sessionData.sessionNames)
      "the enabled NixOS module does not register the rekta session";
    assert lib.assertMsg (lib.elem enabled.programs.rekta-shell.package enabled.systemd.packages)
      "the enabled NixOS module does not hand its package to systemd";
    assert lib.assertMsg
      (lib.elem enabled.programs.rekta-shell.package enabled.environment.systemPackages)
      "the enabled NixOS module leaves its package out of the system's packages";
    assert lib.assertMsg (lib.any (
      a: !a.assertion && lib.hasInfix "plasma6" a.message
    ) withoutPlasma.assertions) "the NixOS module accepts a system without Plasma 6";
    pkgs.runCommand "rekta-shell-nixos-module" { } ''
      test "$(${enabled.programs.rekta-shell.package}/bin/rekta-shell --version)" = "$(${versioned}/bin/rekta-shell --version)"
      # The wrapper names the package's defaults file, and the option's value stands in it.
      names_defaults() {
        if ! grep -q "REKTA_DEFAULTS=.$1/share/rekta-shell/defaults.json." "$1/bin/.rekta-shell-wrapped" ||
          ! grep -qF "\"background\":\"$2\"" "$1/share/rekta-shell/defaults.json"; then
          echo "the module's package does not carry background $2 as its default" >&2
          exit 1
        fi
      }
      for unit in ${lib.escapeShellArgs userUnits}; do
        test -f ${
          enabled.environment.etc."systemd/user".source
        }/$unit || { echo "the enabled module leaves $unit out of /etc/systemd/user" >&2; exit 1; }
      done
      names_defaults ${(enabled.programs.rekta-shell.package).unversioned} solid
      names_defaults ${((withBackground "rekta").programs.rekta-shell.package).unversioned} rekta
      if grep -q density ${enabled.programs.rekta-shell.package}/share/rekta-shell/defaults.json; then
        echo "the module names a density without being asked to" >&2
        exit 1
      fi
      grep -qF "\"density\":\"comfortable\"" ${(withDensity "comfortable").programs.rekta-shell.package}/share/rekta-shell/defaults.json || {
        echo "the density option is not in the package defaults" >&2
        exit 1
      }
      defaults=${enabled.programs.rekta-shell.package}/share/rekta-shell/defaults.json
      if grep -q -e searchEscape -e showRecent -e contrast -e transparency $defaults; then
        echo "the module names a search escape, showRecent, contrast or transparency without being asked to" >&2
        exit 1
      fi
      chosen=${
        (withSettings {
          searchEscape = "back";
          showRecent = false;
          contrast = "more";
          transparency = "reduce";
        }).programs.rekta-shell.package
      }/share/rekta-shell/defaults.json
      grep -qF '"searchEscape":"back"' $chosen && grep -qF '"showRecent":false' $chosen && grep -qF '"contrast":"more"' $chosen && grep -qF '"transparency":"reduce"' $chosen || {
        echo "the search escape, showRecent, contrast or transparency option is not in the package defaults" >&2
        exit 1
      }
      # With both modules on, whichever rekta-settings comes first in PATH names the same defaults.
      profile=${
        (homeConfig [
          { programs.rekta-shell.enable = true; }
        ]).programs.rekta-shell.package.unversioned
      }
      system=${enabled.programs.rekta-shell.package.unversioned}
      for package in $profile $system; do
        grep -q "REKTA_DEFAULTS=.$system/share/rekta-shell/defaults.json." $package/bin/.rekta-settings-wrapped || {
          echo "$package/bin/rekta-settings does not name the system's defaults.json" >&2
          exit 1
        }
      done
      if grep -q REKTA_DEFAULTS ${rekta-shell}/bin/.rekta-shell-wrapped; then
        echo "the package without defaults names a defaults file" >&2
        exit 1
      fi
      touch $out
    '';

  home-module =
    let
      enabled = homeConfig [ { programs.rekta-shell.enable = true; } ];
    in
    assert lib.assertMsg (
      (homeConfig [ ]).home.packages == [ ]
    ) "the home-manager module adds packages with its defaults";
    assert lib.assertMsg (lib.elem enabled.programs.rekta-shell.package enabled.home.packages)
      "the enabled home-manager module leaves its package out of home.packages";
    assert lib.assertMsg (
      lib.elem pkgs.atkinson-hyperlegible-next enabled.home.packages && enabled.fonts.fontconfig.enable
    ) "the enabled home-manager module does not install the typeface";
    assert lib.assertMsg (
      !lib.elem pkgs.atkinson-hyperlegible-next
        (homeConfig [
          {
            programs.rekta-shell = {
              enable = true;
              installFont = false;
            };
          }
        ]).home.packages
    ) "installFont = false still installs the typeface in the profile";
    assert lib.assertMsg (
      !(homeConfig [
        {
          programs.rekta-shell.enable = true;
          fonts.fontconfig.enable = false;
        }
      ]).fonts.fontconfig.enable
    ) "the home-manager module overrides a user's own fonts.fontconfig.enable = false";
    assert lib.assertMsg (removedOptionStops
      (homeConfig [ { programs.rekta-shell.startTempo = "rekta"; } ]).assertions
    ) "a start tempo set in the home-manager module does not stop the build with the reason";
    assert lib.assertMsg (
      !removedOptionStops (homeConfig [ ]).assertions
    ) "the home-manager module stops a build that sets no start tempo";
    pkgs.runCommand "rekta-shell-home-module" { } ''
      test "$(${enabled.programs.rekta-shell.package}/bin/rekta-shell --version)" = "$(${versioned}/bin/rekta-shell --version)"
      touch $out
    '';

  # The Fedora VM's source ISO must list exactly the tracked files, whatever else lies in the checkout.
  fedora-source-iso =
    pkgs.runCommand "rekta-shell-fedora-source-iso"
      {
        nativeBuildInputs = [
          pkgs.git
          pkgs.xorriso
          (pkgs.callPackage ./fedora-source-iso.nix { })
        ];
      }
      ''
        cp -r ${self} repo && chmod -R u+w repo && cd repo
        git init -q && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm t
        echo secret > CLAUDE.local.md && echo secret > .privacy-patterns
        echo stray > stray-untracked.txt
        echo uncommitted-change >> README.md
        git ls-files | sort > "$TMPDIR/tracked"
        rekta-fedora-source-iso "$TMPDIR/out.iso"
        xorriso -indev "$TMPDIR/out.iso" -find /src -type f 2>/dev/null \
          | sed "s|^'/src/||; s|'\$||" | sort > "$TMPDIR/listed"
        diff "$TMPDIR/tracked" "$TMPDIR/listed"
        if grep -Fx -e CLAUDE.local.md -e .privacy-patterns -e stray-untracked.txt "$TMPDIR/listed"; then echo "untracked file in the ISO" >&2; exit 1; fi
        xorriso -osirrox on -indev "$TMPDIR/out.iso" -extract /src/README.md "$TMPDIR/readme" 2>/dev/null
        cmp README.md "$TMPDIR/readme"
        touch $out
      '';

  # The built version comes from the spec's base plus the commit, in the package's name, its programs and the shell's
  # unit alike; the cached build under it knows only the spec.
  built-version-follows-the-spec = pkgs.runCommand "rekta-shell-built-version-follows-the-spec" { } ''
    base=$(sh ${../packaging/version.sh} base ${../packaging/fedora/rekta-shell.spec})
    test -n "$base"
    version=$(${versioned}/bin/rekta-shell --version)
    echo "$version"
    case $version in
      "rekta-shell $base+"?*) ;;
      *) echo "expected 'rekta-shell $base+<commit>', got '$version'" >&2; exit 1 ;;
    esac
    case ${versioned} in
      *"-rekta-shell-$base+"?*) ;;
      *) echo "the store name ${versioned} does not carry $base and the commit" >&2; exit 1 ;;
    esac
    case ${rekta-shell} in
      *"-rekta-shell-$base"|*"-rekta-shell-$base+"*) ;;
      *) echo "the store name ${rekta-shell} does not carry $base" >&2; exit 1 ;;
    esac
    grep -F "REKTA_VERSION='${"$"}{version#rekta-shell }'" ${versioned}/bin/rekta-shell
    grep -F "REKTA_VERSION='${"$"}{version#rekta-shell }'" ${versioned}/bin/rekta-settings
    grep -Fx "ExecStart=${versioned}/bin/rekta-shell" ${versioned}/lib/systemd/user/rekta-shell.service
    # The cached build, started by hand, reports the spec's version alone.
    test "$(${rekta-shell}/bin/rekta-shell --version)" = "rekta-shell $(sh ${../packaging/version.sh} tag ${../packaging/fedora/rekta-shell.spec})"
    touch $out
  '';

  # The release script keeps the base and orders session releases for dnf; rpm's own comparison is the judge.
  release-schema =
    pkgs.runCommand "rekta-shell-release-schema"
      {
        nativeBuildInputs = [
          pkgs.git
          pkgs.rpm
        ];
      }
      ''
                export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid
                export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
                git init -q --bare origin.git
                git init -q -b main repo && cd repo
                mkdir -p scripts packaging/fedora bin
                cp ${../scripts/release.sh} scripts/release.sh
                cp ${../packaging/version.sh} packaging/version.sh
                cp ${../packaging/fedora/ci-check-tag.sh} packaging/fedora/ci-check-tag.sh
                cp ${../packaging/fedora/ci-safe-names.sh} packaging/fedora/ci-safe-names.sh
                cp ${../packaging/fedora/rekta-shell.spec} packaging/fedora/rekta-shell.spec
                chmod +x scripts/release.sh
                printf '#!/bin/sh\nexit 0\n' > scripts/scan-secrets.sh && chmod +x scripts/scan-secrets.sh
                printf 'notes\n' > "$TMPDIR/notes"
                # gh as a stand-in that reports every workflow green
                printf '#!/bin/sh\nprintf "privacy completed success\\nnix completed success\\nrpm completed success\\n"\n' > "$TMPDIR/gh"
                chmod +x "$TMPDIR/gh"; export PATH=$TMPDIR:$PATH
                git add -A && git commit -qm base && git remote add origin ../origin.git && git push -q origin main

                version() { sh packaging/version.sh "$1"; }
                newer() { test "$(rpm --eval "%{lua: print(rpm.vercmp('$1', '$2'))}")" = 1; }
                release() { git push -q origin main; bash scripts/release.sh "$@"; }

                base=$(version base)
                RELEASE_STAMP=20261122.1830 release "$TMPDIR/notes" >/dev/null
                first=$(version rpm)
                test "$(version base)" = "$base"
                test "$(version tag)" = "$base+20261122.1830.$(git rev-parse --short=7 HEAD~1)"
                git tag -l "v$(version tag)" | grep -Fx "v$(version tag)"
                git check-ref-format "refs/tags/v$(version tag)"
                sh packaging/fedora/ci-check-tag.sh "v$(version tag)"

                git commit -q --allow-empty -m work
                RELEASE_STAMP=20261122.1900 release "$TMPDIR/notes" >/dev/null
                second=$(version rpm)
                git commit -q --allow-empty -m more
                RELEASE_STAMP=20261123.0900 release "$TMPDIR/notes" >/dev/null
                third=$(version rpm)
                git commit -q --allow-empty -m newer
                release 0.9.0 "$TMPDIR/notes" >/dev/null
                newbase=$(version rpm)
                test "$newbase" = 0.9.0
                test "$(version tag)" = 0.9.0

                newer "$first" "$base"
                newer "$second" "$first"
                newer "$third" "$second"
                newer "$newbase" "$third"
                newer 0.1.6 "$third"

                git commit -q --allow-empty -m lower
                if release 0.2.0 "$TMPDIR/notes" 2>/dev/null; then echo "a lower base was accepted" >&2; exit 1; fi

                git commit -q --allow-empty -m same
                if release 0.9.0 "$TMPDIR/notes" 2>"$TMPDIR/err"; then echo "the current base was accepted again" >&2; exit 1; fi
                grep -F "not above" "$TMPDIR/err"
                git commit -q --allow-empty -m tenth
                release 0.10.0 "$TMPDIR/notes" >/dev/null
                test "$(version base)" = 0.10.0
                newer 0.10.0 0.9.0

                # release assets keep to characters GitHub leaves alone, and SHA256SUMS then names files that exist
                mkdir assets && cd assets
                touch "rekta-shell-0.1.5^20261122.1830gitabc1234-1.fc45.x86_64.rpm" "rekta-shell-0.1.5^20261122.1830gitabc1234-1.fc45.src.rpm"
                sh ../packaging/fedora/ci-safe-names.sh .
                ls > "$TMPDIR/names"
                test "$(cat "$TMPDIR/names")" = "rekta-shell-0.1.5.20261122.1830gitabc1234-1.fc45.src.rpm
        rekta-shell-0.1.5.20261122.1830gitabc1234-1.fc45.x86_64.rpm"
                sha256sum *.rpm > SHA256SUMS && sha256sum --check SHA256SUMS >/dev/null
                touch $out
      '';

  formatting = pkgs.runCommand "rekta-shell-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    find ${self} -name '*.nix' -print0 | xargs -0 nixfmt --check
    touch $out
  '';
}
