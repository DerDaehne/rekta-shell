{ callPackage }:

# The tests' other end of the bus, the QML module DBusCounterpart, built like the DBus module it tests.
(callPackage ./dbus.nix { }).overrideAttrs {
  pname = "rekta-shell-dbus-counterpart";
  src = ../tests/counterpart;
}
