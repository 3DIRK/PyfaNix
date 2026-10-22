{
  description = "Pyfa - Python Fitting Assistant";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyfa-src = {
      url = "github:pyfa-org/Pyfa";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, pyfa-src }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      overlays.default = final: prev: {
        pyfa = self.packages.${final.stdenv.hostPlatform.system}.default;
      };

      packages = forAllSystems (pkgs:
        let
          python = pkgs.python3;
          pythonEnv = python.withPackages (ps: with ps; [
            beautifulsoup4
            cryptography
            logbook
            markdown2
            matplotlib
            numpy
            packaging
            pillow
            python-dateutil
            python-jose
            pyyaml
            requests
            requests-cache
            roman
            sqlalchemy
            wxpython
          ]);
        in {
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.pyfa;
          pyfa = pkgs.stdenv.mkDerivation {
            pname = "pyfa";
            version = "git";
            src = pyfa-src;

            nativeBuildInputs = [
              pkgs.copyDesktopItems
              pkgs.makeWrapper
            ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.wrapGAppsHook3
            ];

            buildInputs = [
              pythonEnv
            ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.gtk3
              pkgs.librsvg
            ];

            desktopItems = [
              (pkgs.makeDesktopItem {
                name = "pyfa";
                exec = "pyfa";
                icon = "pyfa";
                desktopName = "Pyfa";
                genericName = "Fitting Assistant";
                comment = "Python Fitting Assistant for EVE Online";
                categories = [ "Game" ];
              })
            ];

            postPatch = ''
              substituteInPlace gui/utils/dark.py \
                --replace-fail "app = app or wx.GetApp()" "return False"
            '';

            buildPhase = ''
              runHook preBuild
              ${pythonEnv}/bin/python db_update.py
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/pyfa $out/bin $out/share/icons/hicolor/64x64/apps
              cp -r . $out/share/pyfa
              install -Dm644 imgs/gui/pyfa64.png $out/share/icons/hicolor/64x64/apps/pyfa.png

              makeWrapper ${pythonEnv}/bin/python $out/bin/pyfa \
                --add-flags "$out/share/pyfa/pyfa.py"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Python Fitting Assistant for EVE Online";
              homepage = "https://github.com/pyfa-org/Pyfa";
              license = licenses.gpl3Plus;
              mainProgram = "pyfa";
              platforms = platforms.all;
            };
          };
        }
      );

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/pyfa";
          meta.description = "Pyfa - Python Fitting Assistant";
        };
      });
    };
}
