BrandingMinimalExample: the smallest custom branding plugin

This plugin sets one custom branding color, color_brand, and nothing else. Buttons,
the active navigation-bar button, and selection become mid orange, in both
Dark and Light. Informative notifications stay Victron blue. Everything else
stays as Victron's: the backgrounds, text colors, fonts, status colors, and
logos.

The rules that a Branding file must follow, and the list of Branding
properties, are in .github/branding-plugins.md in the gui-v2 source.
examples/BrandingExample shows a fuller custom branding plugin, with backgrounds and
logos.

1) Compile this plugin for gui-v2 using the gui-v2-plugin-compiler

Either: run the following in a terminal which has sourced the Venus OS SDK environment:

python3 ../../tools/gui-v2-plugin-compiler.py --branding Branding.qml

Alternatively: copy the contents of this directory to the device, ssh in, and compile it on device (requires Large image):

rsync -avc . root@gx.device.ip.address:/tmp/BrandingMinimalExample/
ssh root@gx.device.ip.address
cd /tmp/BrandingMinimalExample/
python3 /opt/victronenergy/gui-v2/gui-v2-plugin-compiler.py --branding Branding.qml

The compiler first checks Branding.qml: the imports, and a few names that
must not appear (see .github/branding-plugins.md). It does not check the
color. Fix each problem that it reports at file:line:column, and compile
again.

2) The compiler writes the custom branding, `BrandingMinimalExample-custom-branding.json`.
The GUI applies a custom branding only while it is the one selected in
com.victronenergy.appmanager /CustomBranding, and reads it from
/run/gx-apps/apps/<name>/custom-branding/<name>.json, where venus-app-manager
installs an app's custom branding. So ship it as the `customBranding`
component of a GX app. The app's name must be the custom branding's "name",
which is the directory name. An app name is lowercase, and a plugin name
cannot have a '-', so compile a copy of this directory named `brandingminimalexample`.
Add the app with venus-app-manager, enable it, then select its custom
branding:
`dbus -y com.victronenergy.appmanager /GxApps/brandingminimalexample/Enable SetValue 1`
`dbus -y com.victronenergy.appmanager /CustomBranding SetValue brandingminimalexample`

Once the app is installed, adding
`--install gx.device.ip.address --ssh-key <private-key>` to the compile
command in step 1 copies the custom branding over the app's file, and the GUI
applies it again.

3) The GUI follows /CustomBranding, and reads the custom branding file again
when it changes, so the colors change straight away.
4) Switch Settings -> General -> Display & Appearance -> GX display appearance
between Dark and Light: the brand color is orange in both.
5) To go back to Victron's colors, select no custom branding:
`dbus -y com.victronenergy.appmanager /CustomBranding SetValue ""`