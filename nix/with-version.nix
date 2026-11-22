# The package as users get it: the cached build plus the commit behind the version, in the thin layer only, so a commit
# that leaves the sources alone changes no more than this wrapper. The units and programs it replaces point at the
# wrapper, so the running session reports the same version as the command.
{
  lib,
  symlinkJoin,
  makeWrapper,
  rekta-shell,
  # "+abc1234", "+abc1234-dirty"; empty leaves the build as it is.
  suffix ? "",
}:

let
  version = (import ./version.nix { inherit lib; }).base + suffix;
in
if suffix == "" then
  rekta-shell
else
  symlinkJoin {
    name = "rekta-shell-${version}";
    paths = [ rekta-shell ];
    nativeBuildInputs = [ makeWrapper ];
    passthru = {
      inherit (rekta-shell) quickshell providedSessions;
      unversioned = rekta-shell;
    };
    postBuild = ''
      for program in rekta-shell rekta-settings; do
        rm $out/bin/$program
        makeWrapper ${rekta-shell}/bin/$program $out/bin/$program --set REKTA_VERSION ${version}
      done
      # The user units NixOS looks for sit in lib/systemd/user; the shell's runs the wrapper.
      rm $out/lib/systemd/user
      mkdir $out/lib/systemd/user
      ln -s ${rekta-shell}/share/systemd/user/* $out/lib/systemd/user/
      rm $out/lib/systemd/user/rekta-shell.service
      sed "s|^ExecStart=.*|ExecStart=$out/bin/rekta-shell|" ${rekta-shell}/share/systemd/user/rekta-shell.service \
        > $out/lib/systemd/user/rekta-shell.service
    '';
  }
