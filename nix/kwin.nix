{ runCommand }:

# KWin's share of the rekta session: its effects and the kwinrc defaults that enable them. Profiles link share/kwin and
# etc/xdg into every session's XDG dirs, so both live under share/rekta-kwin instead, where only the rekta session looks:
# share/rekta-kwin goes on its XDG_DATA_DIRS (KWin finds kwin/effects there) and share/rekta-kwin/kwin on its
# XDG_CONFIG_DIRS (kwinrc).
runCommand "rekta-kwin" { } ''
  mkdir -p $out/share/rekta-kwin
  cp -r ${../kwin} $out/share/rekta-kwin/kwin
''
