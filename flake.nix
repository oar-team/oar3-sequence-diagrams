{
  description = "An over-engineered Hello World in bash";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in

    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        rec {
          diagrams = with nixpkgsFor.${system}; stdenv.mkDerivation rec {
            name = "sequence-diagram";
            src = pkgs.lib.sourceByRegex ./. [
              "^sources"
              "^sources/.*\.pu"
            ];
            buildInputs = [ pkgs.plantuml ];
            buildPhase = ''
              set -x
              for file in sources/*.pu; do
                plantuml $file -tpng
                plantuml $file -tsvg
              done
            '';
            installPhase = ''
              mkdir -p $out
              mv sources/*.png $out/
            '';
          };
          default = diagrams;
        });

      devShells = forAllSystems (system:
        {
          default = nixpkgsFor.${system}.mkShell {
            buildInputs = with nixpkgsFor.${system}; [
              plantuml
            ];
          };
        })
      ;

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems
        (system:
          with nixpkgsFor.${system};
          {
            inherit (self.packages.${system}) diagrams;
          }
        );
    };
}
