{ pkgs, self }:

let
  rekta-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell;
  rekta-qmllint = pkgs.callPackage ./qmllint.nix { inherit (rekta-shell) quickshell; };
  dist = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-design-dist;
  qt = pkgs.kdePackages;
in
{
  package = rekta-shell;

  qmllint = pkgs.runCommand "rekta-shell-qmllint" { LANG = "C.UTF-8"; } ''
    find ${../shell} ${../tests} -name '*.qml' -print0 | xargs -0 ${pkgs.lib.getExe rekta-qmllint} -I ${../shell}
    touch $out
  '';

  tokens-drift =
    pkgs.runCommand "rekta-shell-tokens-drift" { nativeBuildInputs = [ pkgs.nodejs ]; }
      ''
        node ${../scripts/generate-tokens.mjs} ${dist} ${../shell} --check
        touch $out
      '';

  generator-tests =
    pkgs.runCommand "rekta-shell-generator-tests" { nativeBuildInputs = [ pkgs.nodejs ]; }
      ''
        export HOME="$TMPDIR"
        REKTA_DESIGN_DIST=${dist} node --test ${../scripts}/generate-tokens.test.mjs
        touch $out
      '';

  qml-tests =
    pkgs.runCommand "rekta-shell-qml-tests"
      {
        nativeBuildInputs = [ qt.qtdeclarative ];
        QT_QPA_PLATFORM = "offscreen";
        QT_QUICK_BACKEND = "software";
        FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.atkinson-hyperlegible-next ]; };
        QT_PLUGIN_PATH = "${qt.qtbase}/lib/qt-6/plugins";
        QML_IMPORT_PATH = "${qt.qtdeclarative}/lib/qt-6/qml";
        LANG = "C.UTF-8";
      }
      ''
        export HOME="$TMPDIR"
        qmltestrunner -import ${../shell} -input ${../tests}
        # Tests save contact sheets into the working directory; they end up in the check's result for review.
        mkdir $out
        cp *.png $out/ 2>/dev/null || true
      '';

  formatting = pkgs.runCommand "rekta-shell-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    find ${self} -name '*.nix' -print0 | xargs -0 nixfmt --check
    touch $out
  '';
}
