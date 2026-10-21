{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  kdePackages,
}:

# The QML is written against Quickshell 0.3; a new minor or major must be adopted on purpose.
assert lib.assertMsg (
  lib.versions.majorMinor quickshell.version == "0.3"
) "rekta-shell needs Quickshell 0.3.x, but nixpkgs provides ${quickshell.version}";

let
  plasma-workspace = kdePackages.plasma-workspace;
in
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
      --prefix QML_IMPORT_PATH : "$out/share/rekta-shell:${plasma-workspace}/lib/qt-6/qml"

    install -Dm644 ${../session/rekta.desktop} $out/share/wayland-sessions/rekta.desktop
    install -Dm755 ${../session/rekta-session} $out/libexec/rekta-session
    mkdir -p $out/lib/systemd
    cp -r --no-preserve=mode ${../session/systemd} $out/lib/systemd/user
    substituteInPlace $out/share/wayland-sessions/rekta.desktop $out/libexec/rekta-session \
      $out/lib/systemd/user/rekta-shell.service \
      --subst-var out --subst-var-by plasmaWorkspace ${plasma-workspace}
    runHook postInstall
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
