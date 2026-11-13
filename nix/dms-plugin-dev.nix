{ writeShellApplication, watchexec }:
writeShellApplication {
  name = "dms-plugin-dev";
  runtimeInputs = [ watchexec ];
  text = ''
    usage() {
      cat <<EOF
    Usage: dms-plugin-dev [-r] <pluginId>

    Watches ~/.config/dms/plugins/<pluginId> and reloads the plugin in the
    running DMS on every save.

      -r  restart the whole shell instead (dms restart). Use this when a change
          to a file the main component imports (a singleton service, a helper
          QML type) doesn't show up: a plugin reload only re-reads its
          entry points, Qt keeps imported types cached until restart.
    EOF
    }

    restart=0
    while getopts rh opt; do
      case $opt in
        r) restart=1 ;;
        *) usage; exit 0 ;;
      esac
    done
    shift $((OPTIND - 1))
    [ $# -eq 1 ] || { usage; exit 2; }
    id=$1

    dir="''${XDG_CONFIG_HOME:-$HOME/.config}/dms/plugins/$id"
    [ -e "$dir/plugin.json" ] || {
      echo "No live plugin at $dir (is it in modules.desktop.dmsPlugins.live?)" >&2
      exit 1
    }
    dir=$(realpath "$dir")

    if [ "$restart" = 1 ]; then
      cmd=(dms restart)
    else
      cmd=(dms ipc call plugin-scan reload "$id")
    fi

    echo "Watching $dir -> ''${cmd[*]}"
    exec watchexec --watch "$dir" --exts qml,js,json,sh,py --debounce 300ms \
      --postpone --quiet -- "''${cmd[@]}"
  '';
}
