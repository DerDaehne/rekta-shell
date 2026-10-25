{
  stdenv,
  cmake,
  kdePackages,
}:

# The shell's DBus module, RektaShell.DBus, for Quickshell's process: it must come from the same pkgs as Quickshell,
# so both link the same Qt.
stdenv.mkDerivation {
  pname = "rekta-shell-dbus";
  version = "0.1.0";

  src = ../plugins/dbus;

  nativeBuildInputs = [ cmake ];
  buildInputs = [
    kdePackages.qtbase
    kdePackages.qtdeclarative
  ];
  dontWrapQtApps = true;
}
