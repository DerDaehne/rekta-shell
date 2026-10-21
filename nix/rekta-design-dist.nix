{
  runCommand,
  nodejs,
  src,
}:

# Rekta Design's dist/ is not in its git tree; its build has no dependencies and needs no network.
runCommand "rekta-design-dist" { nativeBuildInputs = [ nodejs ]; } ''
  cp -r ${src} source
  chmod -R u+w source
  node source/scripts/build.mjs
  cp -r source/dist $out
''
