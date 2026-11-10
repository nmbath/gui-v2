# gui-v2 Plugin Examples

Example plugins demonstrating each integration type supported by the
gui-v2 plugin system. See each example's README.txt for build and
deploy instructions.

## Integration Types

| Type | Name                       | Where it appears                                     | Example                              |
| ---- | -------------------------- | ---------------------------------------------------- | ------------------------------------ |
| 1    | **PluginSettingsPage**     | Settings > Integrations > UI Plugins > *your plugin* | `SimpleExample/`, `SimpleTrExample/` |
| 2    | **DeviceListSettingsPage** | Device list settings for a specific product ID       | `DeviceListExample/`                 |
| 3    | **NavigationPage**         | Main navigation bar, at a named location (default: `BeforeNotifications`). The location name is the last compiler argument; an integer is an error. | `NavigationExample/`                 |
| 4    | **QuickAccessPane**        | Status bar icon that opens a full pane overlay       | `QuickAccessExample/`                |
| 5    | **QuickAccessPaneCard**    | Card injected into the Controls or Switches pane     | `CardExample/`                       |

A single plugin can combine multiple integration types (e.g. a settings
page and a navigation page in one JSON file).

## Building Plugins

All examples use `tools/gui-v2-plugin-compiler.py`. Requirements:
Python 3, and the Qt tools `lupdate`, `lrelease` and `rcc` in PATH.

```
cd examples/SimpleExample/
python3 ../../tools/gui-v2-plugin-compiler.py \
    --settings SimpleExample_PageSettingsSimple.qml
```

This produces a `.json` file containing the compiled QML resources.

## Deploying to Device

On a GX device, gui-v2 loads only the plugins of the GX apps that
venus-app-manager has installed and enabled: each enabled app's
`/run/gx-apps/apps/<name>/gui-v2/<name>.json`. A file copied anywhere else
by hand is not loaded.

1. Compile a copy of the example in a directory named as the app, for
   example `myplugin`. The plugin's name is the directory name, and
   venus-app-manager requires it to be the app's `name`. An app name is
   lowercase, and a plugin name cannot have a `-`, so use lowercase letters
   and digits.
2. Ship `myplugin-gui-v2.json` as the `gui` component of a GX app named
   `myplugin`, and add the app with venus-app-manager.
3. Enable it:

```
ssh root@venus.local
dbus -y com.victronenergy.appmanager /GxApps/myplugin/Enable SetValue 1
```

gui-v2 loads the plugin straight away. To try a new build of the plugin, add
`--install venus.local --ssh-key <private-key>` to the compile command: it
copies the plugin over the installed app's file, and gui-v2 loads it again.

To remove it, disable the app, which unloads the plugin:

```
dbus -y com.victronenergy.appmanager /GxApps/myplugin/Enable SetValue 0
```

## Examples

### SimpleExample (Type 1)

Minimal plugin with a single settings page. Appears under
Settings > Integrations > UI Plugins.

### SimpleTrExample (Type 1)

Same as SimpleExample but with French translations via `.ts` files.

### DeviceListExample (Type 2)

Injects custom pages into the device list for devices matching
product ID `0x106` (Skylla-i 24/100).

### NavigationExample (Type 3)

Adds a page to the main nav bar with a brick icon. The page is a
`PluginPage` and imports only `Victron.GuiPlugins`. It draws four tiles
of battery, DC PV and DC system values, with `PluginPalette` colors and
text sizes, in a grid in landscape layout and a column in portrait
layout.

### QuickAccessExample (Type 4)

Adds a brick icon to the status bar. Clicking it opens a full-screen
overlay pane (like the built-in Controls and Switches panes) with
battery, solar and pump cards, laid out and scrolled as in the Controls
pane. The pump card has a local toggle.

### CardExample (Type 5)

Injects a compact dashboard card into the Controls pane showing
battery, solar, water, and a water pump switch alongside
the built-in ESS, EVCS, and inverter cards.

### FullApiExample

Uses every type in `Victron.GuiPlugins`. See its README.txt.

### BrandingExample

A custom branding plugin. The rules are in `.github/branding-plugins.md`.

### BrandingMinimalExample

The smallest custom branding plugin. The rules are in
`.github/branding-plugins.md`.
