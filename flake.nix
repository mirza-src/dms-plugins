{
  description = "DankMaterialShell plugins, forked and maintained for my own setup";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      # One package per plugin directory (named by its plugin.json id), plus
      # dms-plugin-dev, the live-reload watcher.
      packages = forAllSystems (system: import ./nix { pkgs = nixpkgs.legacyPackages.${system}; });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
