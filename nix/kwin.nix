{ runCommand }:

# KWin's share of the rekta session: its effects and the defaults that enable them. Only the rekta session puts this
# on XDG_DATA_DIRS and XDG_CONFIG_DIRS, so a Plasma session on the same system neither lists nor loads them.
runCommand "rekta-kwin" { } ''
  mkdir -p $out/share/kwin $out/etc/xdg
  cp -r ${../kwin/effects} $out/share/kwin/effects
  cp ${../kwin/kwinrc} $out/etc/xdg/kwinrc
''
