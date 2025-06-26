{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default";
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pre-commit-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (system: {
      homeManagerModules.default =
        { config, ... }:
        let
          inherit (pkgs) lib;

          pkgs = import nixpkgs { inherit system; };

          pythonEnv = pkgs.python3.withPackages (ps: [
            ps.colorthief
            ps.pillow
            ps.numpy

            (ps.buildPythonPackage rec {
              pname = "haishoku";
              version = "1.1.8";
              doCheck = false;

              src = ps.fetchPypi {
                inherit pname version;
                hash = "sha256-5LmhTANYYIGxirzwS0MgFo/qk/9hHoGyvM1dUmn/y9Q=";
              };
            })
            (ps.buildPythonPackage {
              pname = "fast_colorthief";
              version = "0.0.5";
              doCheck = false;
              dontUseCmakeConfigure = true;

              nativeBuildInputs = [
                pkgs.cmake
                ps.setuptools
                ps.setuptools_scm
                ps.scikit-build
              ];

              src = pkgs.fetchgit {
                url = "https://github.com/bedapisl/fast-colorthief";
                rev = "92eda78157bed309ef9c12e85708ae21241e11d0";
                hash = "sha256-0S8YI2DlEMx75vuAxcWzTBCcerLvULdh4nY2k3zdsqg=";
                fetchSubmodules = true;
              };
            })
          ]);

          colourScheme = builtins.fromJSON (
            builtins.readFile "${
              pkgs.runCommand "colour-scheme"
                {
                  buildInputs = with pkgs; [
                    imagemagick
                    jq
                    colorz
                    pythonEnv
                    (pkgs.buildGoModule {
                      pname = "schemer2";
                      version = "5dc8b0208efce6990c7dd0bf7fe3f044d11c65de";
                      vendorHash = null;

                      src = pkgs.fetchFromGitHub {
                        owner = "nixports";
                        repo = "schemer2";
                        rev = "5dc8b0208efce6990c7dd0bf7fe3f044d11c65de";
                        hash = "sha256-/49TRM4B/EVJlj96RQ1RRsGdK2xP95FLkfwngKXL2ZI=";
                      };
                    })
                  ];
                }
                ''
                  mkdir -p $out/wrapper

                  cp ${./wrap.py} $out/wrapper/wrap.py
                  cp -r ${./pywal} $out/wrapper/pywal

                  ${pythonEnv}/bin/python3 $out/wrapper/wrap.py ${config.pywal-nix.backend} ${config.pywal-nix.wallpaper} ${
                    if config.pywal-nix.light then "1" else "0"
                  } | \
                    sed "s/'/\"/g" | \
                    jq 'to_entries | map({"colour\(.key)": .value, "color\(.key)": .value}) | add' > $out/colour-scheme
                ''
            }/colour-scheme"
          );
        in
        {
          options.pywal-nix = {
            wallpaper = lib.mkOption {
              type = lib.types.path;
              default = /path/to/wallpaper.png;
            };

            backend = lib.mkOption {
              type = lib.types.enum [
                "colorthief"
                "colorz"
                "fast_colorthief"
                "haishoku"
                "schemer2"
                "wal"
              ];

              default = "wal";
            };

            light = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };

            colourScheme = lib.mkOption {
              type = lib.types.anything;
            };

            colorScheme = lib.mkOption {
              type = lib.types.anything;
            };

            enableKittyIntegration = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
          };

          config = {
            pywal-nix.colourScheme = {
              inherit (config.pywal-nix) wallpaper;

              colours = colourScheme;
              colors = colourScheme;

              special = {
                background = colourScheme.colour0;
                foreground = colourScheme.colour15;
                cursor = colourScheme.colour15;
              };
            };

            pywal-nix.colorScheme = config.pywal-nix.colourScheme;
          };

          config.programs.kitty.extraConfig = lib.mkIf config.pywal-nix.enableKittyIntegration ''
            foreground ${config.pywal-nix.colourScheme.special.foreground}
            background ${config.pywal-nix.colourScheme.special.background}
            cursor ${config.pywal-nix.colourScheme.special.cursor}
            color0 ${config.pywal-nix.colourScheme.colours.colour0}
            color1 ${config.pywal-nix.colourScheme.colours.colour1}
            color2 ${config.pywal-nix.colourScheme.colours.colour2}
            color3 ${config.pywal-nix.colourScheme.colours.colour3}
            color4 ${config.pywal-nix.colourScheme.colours.colour4}
            color5 ${config.pywal-nix.colourScheme.colours.colour5}
            color6 ${config.pywal-nix.colourScheme.colours.colour6}
            color7 ${config.pywal-nix.colourScheme.colours.colour7}
            color8 ${config.pywal-nix.colourScheme.colours.colour8}
            color9 ${config.pywal-nix.colourScheme.colours.colour9}
            color10 ${config.pywal-nix.colourScheme.colours.colour10}
            color11 ${config.pywal-nix.colourScheme.colours.colour11}
            color12 ${config.pywal-nix.colourScheme.colours.colour12}
            color13 ${config.pywal-nix.colourScheme.colours.colour13}
            color14 ${config.pywal-nix.colourScheme.colours.colour14}
            color15 ${config.pywal-nix.colourScheme.colours.colour15}
          '';
        };

      formatter = nixpkgs.legacyPackages."${system}".nixfmt-rfc-style;

      checks.pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;

        hooks = {
          deadnix.enable = true;
          flake-checker.enable = true;
          nixfmt-rfc-style.enable = true;
          statix.enable = true;
        };
      };

      devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
        inherit (self.checks.${system}.pre-commit-check) shellHook;

        buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
      };
    });
}
