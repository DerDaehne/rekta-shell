{
  description = "rekta-shell: a desktop shell for KDE Plasma 6 on Wayland, built with Quickshell on KWin after Rekta Design";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Only its source is used, not its flake outputs.
    rekta-design = {
      url = "github:DerDaehne/rekta-design/09e0cf292140727fa81b938650e3df53efb58907";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rekta-design,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Builds against the importing configuration's nixpkgs, so Quickshell shares Qt with its Plasma.
      overlays.default = final: _prev: {
        rekta-shell = final.callPackage ./nix/package.nix { };
      };

      packages = eachSystem (pkgs: {
        rekta-shell = pkgs.callPackage ./nix/package.nix { };
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell;
        rekta-design-dist = pkgs.callPackage ./nix/rekta-design-dist.nix { src = rekta-design; };
      });

      apps = eachSystem (
        pkgs:
        let
          rekta-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell;
          app = drv: {
            type = "app";
            program = pkgs.lib.getExe drv;
          };
        in
        {
          tokens = app (
            pkgs.callPackage ./nix/tokens-app.nix {
              dist = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-design-dist;
            }
          );
          nested = app (pkgs.callPackage ./nix/nested.nix { inherit rekta-shell; });
          nested-shot = app (pkgs.callPackage ./nix/nested-shot.nix { });
        }
        // pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          vm = app (
            pkgs.callPackage ./nix/run-test-vm.nix {
              vm = self.nixosConfigurations.test-vm.config.system.build.vm;
            }
          );
        }
      );

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.quickshell
            pkgs.kdePackages.qtdeclarative
            (pkgs.callPackage ./nix/qmllint.nix { })
            pkgs.nodejs
            pkgs.gitleaks
            pkgs.nixfmt
          ];
        };
      });

      checks = eachSystem (pkgs: import ./nix/checks.nix { inherit pkgs self; });

      nixosConfigurations.test-vm = nixpkgs.lib.nixosSystem { modules = [ ./nix/test-vm.nix ]; };

      formatter = eachSystem (pkgs: pkgs.nixfmt-tree);
    };
}
