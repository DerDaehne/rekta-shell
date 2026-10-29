{
  lib,
  stdenv,
  cmake,
  makeWrapper,
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
  # Quickshell loads the DBus module into its own process, so both must link the same Qt.
  qtLibraries = [
    kdePackages.qtbase
    kdePackages.qtdeclarative
  ];
  sameQt = lib.all (qtLibrary: lib.elem (lib.getDev qtLibrary) quickshell.buildInputs) qtLibraries;
  defaultsFile = "${placeholder "out"}/share/rekta-shell/defaults.json";
in
assert lib.assertMsg sameQt
  "rekta-shell's DBus module is built against another Qt than Quickshell ${quickshell.version}";
stdenv.mkDerivation {
  pname = "rekta-shell";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../CMakeLists.txt
      ../shell
      ../session
      ../settings
      ../kwin
      ../plugins/dbus
    ];
  };

  nativeBuildInputs = [
    cmake
    kdePackages.extra-cmake-modules
    makeWrapper
  ];
  buildInputs = qtLibraries ++ [ kdePackages.kwin ];
  dontWrapQtApps = true;

  cmakeFlags = [
    "-DQUICKSHELL=${lib.getExe quickshell}"
    "-DKWIN_WAYLAND_WRAPPER=${kdePackages.kwin}/bin/kwin_wayland_wrapper"
    "-DSTARTPLASMA_WAYLAND=${plasma-workspace}/bin/startplasma-wayland"
    "-DPLASMA_DBUS_RUN_SESSION_IF_NEEDED=${plasma-workspace}/libexec/plasma-dbus-run-session-if-needed"
  ]
  ++ lib.optional (defaults != { }) "-DREKTA_DEFAULTS_FILE=${defaultsFile}";

  # The ECM hook sets the user units' directory under share, where NixOS does not look for units of systemd.packages.
  preConfigure = ''
    appendToVar cmakeFlags "-DKDE_INSTALL_SYSTEMDUSERUNITDIR=${placeholder "out"}/lib/systemd/user"
  '';

  postInstall = ''
    ${lib.optionalString (defaults != { }) ''
      echo ${lib.escapeShellArg (builtins.toJSON defaults)} > ${defaultsFile}
    ''}
    # Only this wrapper lets the shell start apps for real; run from a checkout it only logs them.
    wrapProgram $out/bin/rekta-shell \
      --prefix QML_IMPORT_PATH : "$out/lib/qt-6/qml:${plasma-workspace}/lib/qt-6/qml:${kdePackages.kpipewire}/lib/qt-6/qml" \
      --prefix PATH : ${kdePackages.libkscreen}/bin:${libcanberra-gtk3}/bin:${gnugrep}/bin
    wrapProgram $out/bin/rekta-settings \
      --prefix QML_IMPORT_PATH : "${plasma-workspace}/lib/qt-6/qml"
  '';

  passthru = {
    inherit quickshell;
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
