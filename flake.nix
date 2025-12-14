{
  description = "Dedicated For P1";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    packwiz2nix = {
      url = "github:snylonue/packwiz2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devshell.flakeModule ];

      perSystem =
        {
          pkgs,
          inputs',
          self',
          ...
        }:
        let
          pack = builtins.fromTOML (builtins.readFile ./pack.toml);
          inherit (inputs'.packwiz2nix.packages) buildPackwizModpack;
        in
        {
          devshells.default = {
            packages = with pkgs; [
              packwiz
            ];
          };
          packages = {
            curseforge = pkgs.stdenvNoCC.mkDerivation {
              inherit (pack) version;
              name = "CreativeCall";
              src = ./.;
              buildInputs = with pkgs; [ packwiz ];
              phases = [
                "unpackPhase"
                "buildPhase"
                "installPhase"
              ];
              buildPhase = ''
                packwiz cf export
              '';
              installPhase = ''
                mkdir $out
                mv "${pack.name}-${pack.version}.zip" $out
              '';
            };

            forge =
              let
                minecraftVersion = "1.20.1";
                forgeVersion = pack.versions.forge;
                version = "${minecraftVersion}-${forgeVersion}";
              in
              pkgs.runCommand "forge-${version}"
                {
                  inherit version;
                  nativeBuildInputs = with pkgs; [
                    cacert
                    curl
                    jre_headless
                  ];

                  outputHashMode = "recursive";
                  outputHash = "sha256-rsml/whB8BNTPT3SP62pOBw7nax0+r4dNk0oiiaI9s8=";
                }
                ''
                  mkdir -p "$out"

                  curl https://maven.minecraftforge.net/net/minecraftforge/forge/${version}/forge-${version}-installer.jar -o ./installer.jar
                  java -jar ./installer.jar --installServer "$out"
                '';

            modpack = buildPackwizModpack {
              src = ./.;
              name = "creative-call";
              # packwiz may record file metadata that not gets managed by git
              allowMissingFile = true;
            };

            modpack-client = buildPackwizModpack {
              src = ./.;
              name = "creative-call";
              # packwiz may record file metadata that not gets managed by git
              allowMissingFile = true;
              side = "client";
            };

            server =
              let
                inherit (self'.packages) forge modpack;
              in
              pkgs.stdenvNoCC.mkDerivation {
                inherit (pack) version;
                pname = "creative-call-server";

                dontUnpack = true;
                dontConfigure = true;

                installPhase = ''
                  mkdir -p $out

                  ln -s ${forge}/* $out
                  cp -r ${modpack}/* $out

                  unlink $out/run.sh
                  unlink $out/run.bat
                  cp ${forge}/run.sh ${forge}/run.bat $out
                  chmod +w $out/run.sh $out/run.bat
                  sed -i 's/\(unix_args.txt\) \("\$@"\)/\1 nogui \2/' $out/run.sh
                  sed -i 's/\(win_args.txt\) \(%\*\)/\1 nogui \2/' $out/run.bat
                '';
              };

          };
        };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    };
}
