{ pkgs, self }:

let
  rekta-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell;
  rekta-qmllint = pkgs.callPackage ./qmllint.nix { inherit (rekta-shell) quickshell; };
  dist = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-design-dist;
  qt = pkgs.kdePackages;
  inherit (pkgs) lib;
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

  nixos-module =
    let
      system =
        modules:
        (self.inputs.nixpkgs.lib.nixosSystem {
          modules = [
            {
              nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
              boot.isContainer = true;
              system.stateVersion = "26.11";
            }
          ]
          ++ modules;
        }).config;
      toplevel = modules: (system modules).system.build.toplevel.drvPath;
      # The kind of system the module is imported into, so the comparison sees what it could change there:
      # the display manager's sessions, user units and Plasma's own packages.
      plasma = {
        services.desktopManager.plasma6.enable = true;
        services.displayManager.sddm.enable = true;
      };
      module = self.nixosModules.default;
      enable = {
        programs.rekta-shell.enable = true;
      };
      enabled = system [
        plasma
        module
        enable
      ];
      withoutPlasma = system [
        module
        enable
      ];
    in
    assert lib.assertMsg (
      toplevel [ plasma ] == toplevel [
        plasma
        module
      ]
    ) "importing the NixOS module with its defaults changed the system";
    assert lib.assertMsg (lib.elem "rekta" enabled.services.displayManager.sessionData.sessionNames)
      "the enabled NixOS module does not register the rekta session";
    assert lib.assertMsg (lib.elem enabled.programs.rekta-shell.package enabled.systemd.packages)
      "the enabled NixOS module does not hand its package to systemd";
    assert lib.assertMsg (lib.any (
      a: !a.assertion && lib.hasInfix "plasma6" a.message
    ) withoutPlasma.assertions) "the NixOS module accepts a system without Plasma 6";
    pkgs.runCommand "rekta-shell-nixos-module" { } "touch $out";

  home-module =
    let
      # A stand-in for home-manager's home.packages, so the check needs no home-manager input.
      packages =
        modules:
        (lib.evalModules {
          modules = [
            {
              options.home.packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
              };
            }
            { _module.args.pkgs = pkgs; }
            self.homeManagerModules.default
          ]
          ++ modules;
        }).config.home.packages;
    in
    assert lib.assertMsg (
      packages [ ] == [ ]
    ) "the home-manager module adds packages with its defaults";
    assert lib.assertMsg (lib.elem rekta-shell (packages [
      { programs.rekta-shell.enable = true; }
    ])) "the enabled home-manager module leaves rekta-shell out of home.packages";
    pkgs.runCommand "rekta-shell-home-module" { } "touch $out";

  formatting = pkgs.runCommand "rekta-shell-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    find ${self} -name '*.nix' -print0 | xargs -0 nixfmt --check
    touch $out
  '';
}
