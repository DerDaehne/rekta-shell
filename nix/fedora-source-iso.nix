{
  writeShellApplication,
  coreutils,
  git,
  gnutar,
  xorriso,
}:

# Run inside a git checkout: the ISO holds git archive of the tracked files (with uncommitted changes
# to them, via git stash create), so untracked and ignored files can never reach a guest.
writeShellApplication {
  name = "rekta-fedora-source-iso";
  runtimeInputs = [
    coreutils
    git
    gnutar
    xorriso
  ];
  text = ''
    out=''${1:?usage: rekta-fedora-source-iso <out.iso> [rpm-directory]}
    rpms=''${2:-}

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    mkdir "$work/src"

    tree=$(git stash create || true)
    git archive "''${tree:-HEAD}" | tar -x -C "$work/src"

    graft=(src="$work/src")
    [ -z "$rpms" ] || graft+=(rpms="$rpms")
    xorriso -as mkisofs -quiet -V REKTA_SRC -J -R -o "$out" -graft-points "''${graft[@]}"
  '';
}
