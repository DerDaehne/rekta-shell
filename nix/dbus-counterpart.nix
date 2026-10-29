{
  stdenv,
  cmake,
  kdePackages,
}:

# The tests' other end of the bus, the QML module DBusCounterpart, built with the same Qt as the shell's DBus module.
stdenv.mkDerivation {
  pname = "rekta-shell-dbus-counterpart";
  version = "0.1.0";

  src = ../tests/counterpart;

  nativeBuildInputs = [ cmake ];
  buildInputs = [
    kdePackages.qtbase
    kdePackages.qtdeclarative
  ];
  dontWrapQtApps = true;
}
