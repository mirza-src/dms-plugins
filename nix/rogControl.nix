{ pkgs }:
{
  # plugin.json "requires": asusctl, busctl, gdbus, jq
  runtimeDeps = with pkgs; [
    asusctl
    systemd
    glib
    jq
  ];
}
