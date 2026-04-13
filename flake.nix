{
  description = "Satisfactory Architect — development shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # See: https://ayats.org/blog/no-flake-utils
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs_22 # includes npm
            deno
          ];

          shellHook = ''
            echo "satisfactory-architect dev shell"
            echo ""
            echo "  ui:     cd ui && npm install && npm run dev"
            echo "  server: cd server && deno task start"
            echo "  docker: docker compose up --build"
          '';
        };
      });
    };
}
