{
  lib,
  stdenv,
  cmake,
  kdePackages,
}:

# The fade-back effect is built against KWin's internal headers, which change with every Plasma release.
assert lib.assertMsg (
  lib.versions.majorMinor kdePackages.kwin.version == "6.8"
) "rekta-kwin is written against KWin 6.8, but nixpkgs provides ${kdePackages.kwin.version}";

# KWin's share of the rekta session: its effects and the kwinrc defaults that enable them. Profiles link share/kwin,
# etc/xdg and lib/qt-6/plugins into every session's XDG dirs and plugin path, so all of it lives under share/rekta-kwin
# instead, where only the rekta session looks: share/rekta-kwin goes on its XDG_DATA_DIRS (KWin finds kwin/effects
# there), share/rekta-kwin/kwin on its XDG_CONFIG_DIRS (kwinrc) and share/rekta-kwin/plugins on its QT_PLUGIN_PATH
# (kwin/effects/plugins).
stdenv.mkDerivation {
  pname = "rekta-kwin";
  version = "0.1.0";

  src = ../kwin/fadeback;

  nativeBuildInputs = [
    cmake
    kdePackages.extra-cmake-modules
  ];
  buildInputs = [ kdePackages.kwin ];
  dontWrapQtApps = true;

  postInstall = ''
    mkdir -p $out/share/rekta-kwin/kwin
    mv $out/lib/qt-6/plugins $out/share/rekta-kwin/plugins
    rm -r $out/lib
    cp -r ${../kwin/effects} $out/share/rekta-kwin/kwin/effects
    cp ${../kwin/kwinrc} $out/share/rekta-kwin/kwin/kwinrc
  '';
}
