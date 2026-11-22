# The spec's Version, the one source of the version, in the forms of packaging/version.sh.
{ lib }:
let
  specLines = lib.splitString "\n" (builtins.readFile ../packaging/fedora/rekta-shell.spec);
  rpm = lib.trim (
    lib.removePrefix "Version:" (
      lib.findFirst (lib.hasPrefix "Version:") (throw "the spec has no Version") specLines
    )
  );
in
{
  inherit rpm;
  base = lib.head (lib.splitString "^" rpm);
  tag = builtins.replaceStrings [ "^" "git" ] [ "+" "." ] rpm;
}
