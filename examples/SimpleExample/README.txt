SimpleExample: a plugin that adds a settings page

The page has one switch. It is written with the Victron.GuiPlugins types
(PluginPage, PluginItemListView and PluginListSwitch); a plugin page
must not import Victron.VenusOS. The rules that plugin pages must follow are
in .github/gui-plugins.md in the gui-v2 source.

1) Compile this plugin for gui-v2 using the gui-v2-plugin-compiler

Either: run the following in a terminal which has sourced the Venus OS SDK environment:

python3 ../../tools/gui-v2-plugin-compiler.py \
    --min-required-version v1.4.1 \
    --settings SimpleExample_PageSettingsSimple.qml

Alternatively: copy the contents of this directory to the device, ssh in, and compile it on device (requires Large image):

rsync -avc . root@gx.device.ip.address:/tmp/SimpleExample/
ssh root@gx.device.ip.address
cd /tmp/SimpleExample/
python3 /opt/victronenergy/gui-v2/gui-v2-plugin-compiler.py \
    --min-required-version v1.4.1 \
    --settings SimpleExample_PageSettingsSimple.qml

2) Install it on a GX device as a GX app, and enable it: see "Deploying to Device" in examples/README.md.
3) Or skip the device, and run it on a desktop build: copy `SimpleExample-gui-v2.json` into the `plugins` directory next to the `venus-gui-v2` executable.
4) Run gui-v2 in mock mode, e.g. `/opt/victronenergy/venus-gui-v2 --mock --no-mock-timers`
5) Navigate to Settings -> Integrations -> UI Plugins and confirm the SimpleExample plugin exists
6) Navigate to Settings -> Integrations -> UI Plugins -> SimpleExample to see the settings page
