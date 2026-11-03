NavigationExample - a navigation page

Adds a page to the main navigation bar, with a brick icon. The page is
a PluginPage. It imports only Victron.GuiPlugins, and the list items
draw the text. The rules are in .github/gui-plugins.md.

The page shows battery state of charge, voltage and power, whether the
battery is charging, DC PV power, and DC system power. A positive
battery power value means charging. The pump row is a local switch. It
does not write to the system, and it does not control a pump. Tanks are
not listed: a PluginDataItem cannot enumerate them.

The bar title is the compiler argument below ("Example"). It is shown
as written, and it is not translated. The page title is translated.


1) Compile

  cd examples/NavigationExample/
  python3 ../../tools/gui-v2-plugin-compiler.py \
    --min-required-version v1.4.1 \
    --navigation NavigationExample_Page.qml icon_brick.svg "Example"

This writes NavigationExample.json. The command omits the location, so
the page is inserted before Levels. The location, if given, must be the
last argument and one of: BeforeBoat, BeforeBrief, BeforeOverview,
BeforeLevels, BeforeNotifications, BeforeSettings or AfterSettings. An
integer is an error. A title may be a location name only when another
location name follows it. The gap is not a visible button. BeforeBoat
is still first when Boat is hidden. The page file name must be unique
and must not match a built-in page. The navbar matches the file name
only.

Other examples use v1.4.1 because that is the Victron.GuiPlugins
minimum they need. This page also needs a gui-v2 that loads navigation
pages. The loader rejects a plugin whose minimum is newer than the
running gui-v2.

2) Deploy to a GX device

  scp NavigationExample.json root@venus.local:/tmp/
  ssh root@venus.local
  mkdir -p /data/apps/available/NavigationExample/gui-v2/
  cp /tmp/NavigationExample.json /data/apps/available/NavigationExample/gui-v2/
  ln -sf /data/apps/available/NavigationExample /data/apps/enabled/NavigationExample
  svc -t /service/start-gui

Or add --install <gx-host> --ssh-key <private-key> to the compile
command. That is for testing only.

3) Verify

The navigation bar now shows:

  Boat | Brief | Overview | Example | Levels | Notifications | Settings

Tap the brick icon. The page lists the system values and the pump
switch.
