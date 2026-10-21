{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
}:

# The QML is written against Quickshell 0.3; a new minor or major must be adopted on purpose.
assert lib.assertMsg (
  lib.versions.majorMinor quickshell.version == "0.3"
) "rekta-shell needs Quickshell 0.3.x, but nixpkgs provides ${quickshell.version}";

stdenvNoCC.mkDerivation {
  pname = "rekta-shell";
  version = "0.1.0";

  src = ../shell;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/rekta-shell
    cp -r . $out/share/rekta-shell
    makeWrapper ${lib.getExe quickshell} $out/bin/rekta-shell \
      --add-flags "--path $out/share/rekta-shell" \
      --prefix QML_IMPORT_PATH : "$out/share/rekta-shell"
    runHook postInstall
  '';

  passthru = { inherit quickshell; };

  meta = {
    description = "Desktop shell for KDE Plasma 6 on Wayland, built with Quickshell after Rekta Design";
    homepage = "https://github.com/DerDaehne/rekta-shell";
    license = lib.licenses.mit;
    mainProgram = "rekta-shell";
    platforms = lib.platforms.linux;
  };
}
