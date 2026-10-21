{
  writeShellApplication,
  nodejs,
  dist,
}:

# Regenerates the checked-in token module from the pinned Rekta Design.
writeShellApplication {
  name = "rekta-tokens";
  runtimeInputs = [ nodejs ];
  text = ''
    if [ ! -f flake.nix ] || [ ! -d shell/Rekta ]; then
      echo "rekta-tokens: run it from the repository root" >&2
      exit 2
    fi
    node scripts/generate-tokens.mjs ${dist} shell
  '';
}
