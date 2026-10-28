{
  lib,
  stdenvNoCC,
  makeWrapper,
  callPackage,
  quickshell,
  kdePackages,
  libcanberra-gtk3,
  gnugrep,
  # Settings from the Nix configuration, which the shell takes as its defaults; the user's settings.json wins over them.
  defaults ? { },
}:

# The QML is written against Quickshell 0.3; a new minor or major must be adopted on purpose.
assert lib.assertMsg (
  lib.versions.majorMinor quickshell.version == "0.3"
) "rekta-shell needs Quickshell 0.3.x, but nixpkgs provides ${quickshell.version}";

let
  plasma-workspace = kdePackages.plasma-workspace;
  rekta-kwin = callPackage ./kwin.nix { };
  dbus = callPackage ./dbus.nix { };
  # Quickshell loads the DBus module into its own process, so both must link the same Qt.
  sameQt = lib.all (qtLibrary: lib.elem qtLibrary quickshell.buildInputs) dbus.buildInputs;
in
assert lib.assertMsg sameQt
  "rekta-shell's DBus module is built against another Qt than Quickshell ${quickshell.version}";
stdenvNoCC.mkDerivation {
  pname = "rekta-shell";
  version = "0.1.0";

  src = ../shell;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/rekta-shell
    cp -r . $out/share/rekta-shell
    defaultsArgs=()
    ${lib.optionalString (defaults != { }) ''
      echo ${lib.escapeShellArg (builtins.toJSON defaults)} > $out/share/rekta-shell/defaults.json
      defaultsArgs=(--set REKTA_DEFAULTS $out/share/rekta-shell/defaults.json)
    ''}
    # Only this wrapper lets the shell start apps for real; run from a checkout it only logs them.
    makeWrapper ${lib.getExe quickshell} $out/bin/rekta-shell \
      --add-flags "--path $out/share/rekta-shell" \
      --prefix QML_IMPORT_PATH : "$out/share/rekta-shell:${dbus}/lib/qt-6/qml:${plasma-workspace}/lib/qt-6/qml:${kdePackages.kpipewire}/lib/qt-6/qml" \
      --prefix PATH : ${kdePackages.libkscreen}/bin:${libcanberra-gtk3}/bin:${gnugrep}/bin \
      "''${defaultsArgs[@]}" \
      --set-default REKTA_SHELL_LAUNCH systemd

    # The settings app is a configuration of its own; the wrapper runs it with the same modules as the shell.
    install -Dm644 ${../settings/shell.qml} $out/share/rekta-settings/shell.qml
    install -Dm644 ${../settings/rekta-settings.desktop} $out/share/applications/rekta-settings.desktop
    install -Dm755 ${../settings/rekta-settings} $out/bin/rekta-settings
    substituteInPlace $out/bin/rekta-settings --subst-var out
    wrapProgram $out/bin/rekta-settings \
      --prefix PATH : ${lib.makeBinPath [ quickshell ]} \
      --prefix QML_IMPORT_PATH : "$out/share/rekta-shell:${plasma-workspace}/lib/qt-6/qml"

    install -Dm644 ${../session/rekta.desktop} $out/share/wayland-sessions/rekta.desktop
    install -Dm755 ${../session/rekta-session} $out/libexec/rekta-session
    install -Dm755 ${../session/rekta-kwin} $out/libexec/rekta-kwin
    mkdir -p $out/lib/systemd
    cp -r --no-preserve=mode ${../session/systemd} $out/lib/systemd/user
    substituteInPlace $out/share/wayland-sessions/rekta.desktop $out/libexec/rekta-session $out/libexec/rekta-kwin \
      $out/lib/systemd/user/rekta-shell.service $out/lib/systemd/user/plasma-kwin_wayland.service.d/rekta-session.conf \
      --subst-var out --subst-var-by plasmaWorkspace ${plasma-workspace} \
      --subst-var-by kwin ${kdePackages.kwin} --subst-var-by rektaKwin ${rekta-kwin}
    runHook postInstall
  '';

  passthru = {
    inherit quickshell dbus;
    providedSessions = [ "rekta" ];
  };

  meta = {
    description = "Desktop shell for KDE Plasma 6 on Wayland, built with Quickshell after Rekta Design";
    homepage = "https://github.com/DerDaehne/rekta-shell";
    license = lib.licenses.mit;
    mainProgram = "rekta-shell";
    platforms = lib.platforms.linux;
  };
}
