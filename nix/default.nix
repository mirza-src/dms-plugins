# Every top-level directory with a plugin.json is a plugin. Its package is
# the directory as-is: the same files DMS loads from the live checkout, so
# nothing may be patched in here (no store paths in QML/JS/scripts). Tools a
# plugin runs are found on PATH; list them in nix/<id>.nix as runtimeDeps for
# the system to install.
{ pkgs }:
let
  inherit (pkgs) lib;
  root = ./..;

  pluginIds = lib.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (root + "/${name}/plugin.json")
    ) (builtins.readDir root)
  );

  mkPlugin =
    id:
    let
      dir = root + "/${id}";
      manifest = lib.importJSON (dir + "/plugin.json");
      extra = lib.optionalAttrs (builtins.pathExists ./${id}.nix) (import ./${id}.nix { inherit pkgs; });
    in
    assert lib.assertMsg (manifest.id == id) "${id}/plugin.json has id \"${manifest.id}\"";
    pkgs.stdenvNoCC.mkDerivation {
      pname = "dms-plugin-${id}";
      version = manifest.version or "0";
      # Only this plugin's directory, so editing one doesn't rebuild the rest.
      src = builtins.path {
        path = dir;
        name = "dms-plugin-${id}-source";
      };

      dontConfigure = true;
      dontBuild = true;
      # Keep the files byte-identical to the checkout (no shebang rewriting).
      dontFixup = true;

      installPhase = ''
        runHook preInstall
        cp -r . $out
        runHook postInstall
      '';

      passthru.runtimeDeps = extra.runtimeDeps or [ ];

      meta = {
        description = manifest.description or "";
        license = lib.licenses.mit;
        platforms = lib.platforms.linux;
      };
    };
in
lib.genAttrs pluginIds mkPlugin
// {
  dms-plugin-dev = pkgs.callPackage ./dms-plugin-dev.nix { };
}
