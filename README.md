# dms-plugins

My own [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
plugins, written from scratch for my machines and packaged for Nix.

Each top-level directory is one plugin, named after the `id` in its
`plugin.json` (the layout the [plugin registry](https://github.com/AvengeMedia/dms-plugin-registry)
expects for a monorepo).

## Rules

- **A plugin directory is exactly what DMS loads.** The Nix package copies it
  unchanged; nothing is patched in at build time. That way the live checkout
  and the installed package behave the same.
- **No hardcoded paths, few dependencies.** Talk to system services over
  D-Bus (`busctl`, part of systemd) and to the kernel through sysfs. Tools a
  plugin runs are found on `PATH` and listed in `nix/<id>.nix`
  (`runtimeDeps`); the system installs them.

## Live editing

DMS loads plugins from `~/.config/dms/plugins/<id>` before the system ones in
`/etc/xdg/quickshell/dms-plugins`. Link a plugin directory there (my dotfiles
do it with `modules.desktop.dmsPlugins.live`), then:

```sh
nix run .#dms-plugin-dev -- <id>      # reload the plugin on every save
nix run .#dms-plugin-dev -- -r <id>   # restart the shell on every save
```

Use `-r` when an edit to an imported file (a service singleton or helper
type) doesn't show up after a reload. Qt caches imported types until DMS
restarts.

Remove the link to go back to the installed package.
