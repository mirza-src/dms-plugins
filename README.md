# dms-plugins

My own [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
plugins: forks of community plugins, changed to work the way I want and
packaged cleanly for Nix.

Each top-level directory is one plugin, named after the `id` in its
`plugin.json` (the layout the [plugin registry](https://github.com/AvengeMedia/dms-plugin-registry)
expects for a monorepo). The ids are kept the same as upstream, so a plugin
here replaces the registry one and keeps its settings.

| Plugin       | Forked from                                                               | License |
| ------------ | ------------------------------------------------------------------------- | ------- |
| `rogControl` | [lucianosrp/DmsRogControl](https://github.com/lucianosrp/DmsRogControl)   | MIT     |

Each plugin keeps its upstream `LICENSE`.

## Rules

- **A plugin directory is exactly what DMS loads.** The Nix package copies it
  unchanged; nothing is patched in at build time. That way the live checkout
  and the installed package behave the same.
- **No hardcoded paths.** Run tools by name from `PATH` and list them in
  `nix/<id>.nix` (`runtimeDeps`); the system installs them. Compiled helpers
  get their own package and are found on `PATH` too.

## Live editing

DMS loads plugins from `~/.config/dms/plugins/<id>` before the system ones in
`/etc/xdg/quickshell/dms-plugins`. Link a plugin directory there (my dotfiles
do it with `modules.desktop.dmsPlugins.live`), then:

```sh
nix run .#dms-plugin-dev -- rogControl      # reload the plugin on every save
nix run .#dms-plugin-dev -- -r rogControl   # restart the shell on every save
```

Use `-r` when an edit to an imported file (a service singleton or helper
type) doesn't show up after a reload. Qt caches imported types until DMS
restarts.

Remove the link to go back to the installed package.

## Pulling upstream changes

Each plugin was imported with `git subtree --squash`:

```sh
git subtree pull --prefix rogControl https://github.com/lucianosrp/DmsRogControl main --squash
```

## Adding a plugin

```sh
git subtree add --prefix <id> <upstream-url> <rev> --squash
```

Then add `nix/<id>.nix` if it needs tools on `PATH`, and add a row to the
table above.
