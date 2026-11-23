{ lib, runCommand }:

# The wallpapers in KDE's format, so Plasma's picker finds them too. Only data: no dependency on the shell.
runCommand "rekta-backgrounds"
  {
    meta = {
      description = "Background images of rekta-shell, in KDE's wallpaper format";
      license = lib.licenses.cc0;
    };
  }
  ''
    mkdir -p $out/share/wallpapers $out/share/licenses/rekta-backgrounds
    cp -r ${../backgrounds/rekta-sky} $out/share/wallpapers/rekta-sky
    cp ${../backgrounds/LICENSE} $out/share/licenses/rekta-backgrounds/LICENSE
  ''
