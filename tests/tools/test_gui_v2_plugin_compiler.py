import importlib.util
import json
import os
import tempfile
import unittest
import zipfile
from contextlib import contextmanager
from pathlib import Path


COMPILER = Path(__file__).parents[2] / "tools" / "gui-v2-plugin-compiler.py"
SPEC = importlib.util.spec_from_file_location("gui_v2_plugin_compiler", COMPILER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


@contextmanager
def working_directory(path):
    previous = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(previous)


class PartnerPackManifestTest(unittest.TestCase):
    def make_pack(self, directory):
        Path(directory, "pages").mkdir()
        Path(directory, "assets").mkdir()
        Path(directory, "pages", "Dashboard.qml").write_text("import QtQuick\n", encoding="utf-8")
        Path(directory, "assets", "nav.svg").write_text("<svg/>", encoding="utf-8")
        Path(directory, "assets", "logo.svg").write_text("<svg/>", encoding="utf-8")
        Path(directory, "branding.json").write_text(json.dumps({
            "displayName": "Acme Marine",
            "splashLogo": "assets/logo.svg",
            "colors": {"color_page_background": {"dark": "#001122", "light": "#eef5fa"}},
        }), encoding="utf-8")
        manifest = {
            "schemaVersion": 2,
            "name": "acme-marine",
            "version": "1.0.0",
            "branding": {"definition": "branding.json"},
            "integrations": [{
                "type": "navigationPage",
                "id": "dashboard",
                "title": "Dashboard",
                "icon": "assets/nav.svg",
                "source": "pages/Dashboard.qml",
                "placement": "beforeNotifications",
                "order": 10,
                "capabilities": ["readSystemData"],
            }],
        }
        Path(directory, "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    def test_load_manifest_resolves_owned_resources(self):
        with tempfile.TemporaryDirectory() as directory:
            self.make_pack(directory)
            with working_directory(directory):
                manifest = MODULE.load_manifest("manifest.json")
            self.assertEqual(manifest["schemaVersion"], 2)
            self.assertEqual(manifest["branding"]["splashLogo"], "qrc:/acme-marine/assets/logo.svg")
            self.assertEqual(manifest["integrations"][0]["type"], "navigationPage")
            self.assertEqual(manifest["integrations"][0]["url"], "qrc:/acme-marine/pages/Dashboard.qml")
            self.assertEqual(manifest["integrations"][0]["capabilities"], ["readSystemData"])

    def test_runtime_resource_collection_excludes_documentation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "assets").mkdir()
            (root / "docs" / "screenshots").mkdir(parents=True)
            (root / "assets" / "logo.svg").write_text("<svg/>", encoding="utf-8")
            (root / "docs" / "screenshots" / "guide.png").write_bytes(b"not-runtime")
            with working_directory(directory):
                self.assertEqual(MODULE.collect_filenames(".", ".svg"), ["assets/logo.svg"])
                self.assertEqual(MODULE.collect_filenames(".", ".png"), [])

    def test_compiler_sets_reproducible_resource_timestamp(self):
        self.assertEqual(os.environ["SOURCE_DATE_EPOCH"], "946684800")

    def test_duplicate_navigation_ids_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            self.make_pack(directory)
            path = Path(directory, "manifest.json")
            manifest = json.loads(path.read_text(encoding="utf-8"))
            manifest["integrations"].append(dict(manifest["integrations"][0]))
            path.write_text(json.dumps(manifest), encoding="utf-8")
            with working_directory(directory), self.assertRaisesRegex(ValueError, "duplicate integration id"):
                MODULE.load_manifest("manifest.json")

    def test_invalid_placement_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            self.make_pack(directory)
            path = Path(directory, "manifest.json")
            manifest = json.loads(path.read_text(encoding="utf-8"))
            manifest["integrations"][0]["placement"] = "index42"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            with working_directory(directory), self.assertRaisesRegex(ValueError, "invalid navigation placement"):
                MODULE.load_manifest("manifest.json")

    def test_unsupported_capability_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            self.make_pack(directory)
            path = Path(directory, "manifest.json")
            manifest = json.loads(path.read_text(encoding="utf-8"))
            manifest["integrations"][0]["capabilities"] = ["networkAccess"]
            path.write_text(json.dumps(manifest), encoding="utf-8")
            with working_directory(directory), self.assertRaisesRegex(
                    ValueError, "unsupported capabilities: networkAccess"):
                MODULE.load_manifest("manifest.json")

    def test_canonical_model_1_is_normalized_for_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "assets").mkdir()
            for filename in ("dark.svg", "light.svg", "splash.svg", "browser.svg"):
                Path(directory, "assets", filename).write_text("<svg/>", encoding="utf-8")
            Path(directory, "branding.json").write_text(json.dumps({
                "name": "Bluewater Marine",
                "attribution": "Powered by Victron Energy",
                "logos": {
                    "dark": "assets/dark.svg",
                    "light": "assets/light.svg",
                    "splash": "assets/splash.svg",
                    "browser": "assets/browser.svg",
                },
                "colors": {
                    "primary": "#0B4F6C",
                    "accent": "#23B5D3",
                    "success": "#35C98B",
                    "tanks": {
                        "dark": {
                            "fuel": "#D6C94A", "freshWater": "#55C7E8",
                            "blackWater": "#A58AD8",
                        },
                        "light": {
                            "fuel": "#C2B52F", "freshWater": "#2EA9CD",
                            "blackWater": "#8B6FC0",
                        },
                    },
                    "dark": {
                        "pageBackground": "#071923", "cardBackground": "#102B38",
                        "navigationBackground": "#0B2430", "primaryText": "#F4FAFC",
                        "secondaryText": "#A9C3CE", "divider": "#294653",
                    },
                    "light": {
                        "pageBackground": "#F3F8FA", "cardBackground": "#FFFFFF",
                        "navigationBackground": "#E8F2F5", "primaryText": "#102B38",
                        "secondaryText": "#46636F", "divider": "#CADCE3",
                    },
                },
            }), encoding="utf-8")
            Path(directory, "partner.json").write_text(json.dumps({
                "schemaVersion": 2,
                "id": "bluewater-marine-branding",
                "name": "Bluewater Marine",
                "version": "1.0.0",
                "model": 1,
                "compatibleGuiV2": {"minimum": "1.3.20", "maximum": "1.x"},
                "branding": "branding.json",
                "integrations": [],
            }), encoding="utf-8")

            with working_directory(directory):
                manifest = MODULE.load_manifest("partner.json")
                bootstrap_directory = Path(directory, "wasm-bootstrap")
                MODULE.write_wasm_bootstrap(bootstrap_directory,
                    manifest["name"], manifest["canonicalBranding"])

            self.assertEqual(manifest["name"], "bluewater-marine-branding")
            self.assertEqual(manifest["maxRequiredVersion"], "1.999999")
            self.assertEqual(manifest["branding"]["displayName"], "Bluewater Marine")
            self.assertEqual(manifest["branding"]["logoDark"],
                "qrc:/bluewater-marine-branding/assets/dark.svg")
            self.assertEqual(manifest["branding"]["colors"]["color_page_background"]["dark"],
                "#071923")
            self.assertEqual(manifest["branding"]["colors"]["color_listItem_background"]["dark"],
                "#102B38")
            self.assertEqual(manifest["branding"]["colors"]["color_card_background"]["light"],
                "#FFFFFF")
            self.assertEqual(
                manifest["branding"]["colors"]["color_overviewPage_widget_background"]["dark"],
                "#102B38")
            self.assertEqual(manifest["branding"]["colors"]["color_listItem_background"]["light"],
                "#FFFFFF")
            self.assertEqual(manifest["branding"]["colors"]["color_navigationBar_background"]["dark"],
                "#0B2430")
            self.assertEqual(manifest["branding"]["colors"]["color_font_secondary"]["light"],
                "#46636F")
            self.assertEqual(manifest["branding"]["colors"]["color_listItem_separator"]["dark"],
                "#294653")
            self.assertEqual(manifest["branding"]["colors"]["color_separator"]["light"],
                "#CADCE3")
            self.assertEqual(manifest["branding"]["colors"]["color_brand_accent"], "#23B5D3")
            self.assertEqual(manifest["branding"]["colors"]["color_ok"], "#23B5D3")
            self.assertEqual(manifest["branding"]["colors"]["color_blue"], "#23B5D3")
            self.assertEqual(manifest["branding"]["colors"]["color_success"], "#35C98B")
            self.assertEqual(manifest["branding"]["colors"]["color_fuel"], {
                "dark": "#D6C94A", "light": "#C2B52F",
            })
            self.assertEqual(manifest["branding"]["colors"]["color_freshWater"], {
                "dark": "#55C7E8", "light": "#2EA9CD",
            })
            self.assertEqual(manifest["branding"]["colors"]["color_blackWater"], {
                "dark": "#A58AD8", "light": "#8B6FC0",
            })
            self.assertEqual(
                manifest["branding"]["colors"]["color_brand_accent_muted"]["dark"],
                "#115162")
            self.assertEqual(
                manifest["branding"]["colors"]["color_brand_accent_muted"]["light"],
                "#A8E0EC")
            bootstrap = json.loads(Path(bootstrap_directory, "branding.json").read_text(
                encoding="utf-8"))
            self.assertTrue(bootstrap["logoDark"].endswith("assets/dark.svg"))
            self.assertTrue(bootstrap["logoLight"].endswith("assets/light.svg"))
            self.assertTrue(bootstrap["splashLogo"].endswith("assets/splash.svg"))
            self.assertTrue(bootstrap["favicon"].endswith("assets/browser.svg"))
            self.assertNotIn("frameLogo", bootstrap)
            self.assertNotEqual(bootstrap["logoDark"], bootstrap["logoLight"])

    def test_canonical_position_is_normalized(self):
        self.assertEqual(MODULE.canonical_placement({"after": "overview"}), "afterOverview")

    def test_tank_roles_must_match_between_schemes(self):
        with self.assertRaisesRegex(ValueError, "tank colour roles must match"):
            MODULE.semantic_theme_colors({
                "tanks": {
                    "dark": {"fuel": "#D6C94A"},
                    "light": {"freshWater": "#2EA9CD"},
                }
            })

    def test_unknown_tank_role_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "unsupported tank colour roles: mystery"):
            MODULE.semantic_theme_colors({
                "tanks": {
                    "dark": {"mystery": "#123456"},
                    "light": {"mystery": "#654321"},
                }
            })

    def test_canonical_model_3_contributions_are_normalized(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "assets").mkdir()
            for filename in ("dark.svg", "light.svg", "splash.svg", "browser.svg"):
                (root / "assets" / filename).write_text("<svg/>", encoding="utf-8")
            (root / "branding.json").write_text(json.dumps({
                "name": "Bluewater Marine",
                "logos": {
                    "dark": "assets/dark.svg", "light": "assets/light.svg",
                    "splash": "assets/splash.svg", "browser": "assets/browser.svg",
                },
                "colors": {"dark": {}, "light": {}},
            }), encoding="utf-8")
            (root / "partner.json").write_text(json.dumps({
                "schemaVersion": 2,
                "id": "bluewater-model-3",
                "name": "Bluewater Marine Model 3",
                "version": "1.0.0",
                "model": 3,
                "compatibleGuiV2": {"minimum": "1.3.20", "maximum": "1.x"},
                "branding": "branding.json",
                "integrations": [
                    {
                        "type": "briefMetric", "id": "starter-voltage",
                        "title": "Starter battery", "placement": "sidePanel",
                        "dataSource": "system.firstAdditionalBattery.voltage",
                        "capabilities": ["readSystemData"],
                    },
                    {
                        "type": "overviewEnergyNode", "id": "solar-generation",
                        "title": "Solar generation", "role": "source",
                        "dataSource": "system.solar.power",
                        "capabilities": ["readSystemData"],
                    },
                    {
                        "type": "overviewBattery", "id": "starter-battery",
                        "title": "Starter battery", "batteryRole": "starter",
                        "dataSource": "system.firstAdditionalBattery.stateOfCharge",
                        "capabilities": ["readSystemData"],
                    },
                ],
            }), encoding="utf-8")

            with working_directory(directory):
                manifest = MODULE.load_manifest("partner.json")

            self.assertEqual(manifest["model"], 3)
            self.assertNotIn("url", manifest["integrations"][0])
            self.assertEqual(manifest["integrations"][0]["unit"], "V")
            self.assertEqual(manifest["integrations"][1]["placement"], "source")
            self.assertEqual(manifest["integrations"][2]["placement"], "battery")

    def test_model_3_contribution_is_rejected_from_model_2(self):
        manifest = {
            "schemaVersion": 2,
            "id": "invalid-model-2",
            "name": "Invalid Model 2",
            "version": "1.0.0",
            "model": 2,
            "compatibleGuiV2": {},
            "branding": "branding.json",
            "integrations": [{"type": "briefMetric"}],
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "branding.json").write_text("{}", encoding="utf-8")
            (root / "partner.json").write_text(json.dumps(manifest), encoding="utf-8")
            with working_directory(directory), self.assertRaisesRegex(
                    ValueError, 'Model 3 integrations require'):
                MODULE.load_manifest("partner.json")

    def test_more_than_one_overview_battery_is_rejected(self):
        battery = {
            "type": "overviewBattery", "title": "Starter battery",
            "batteryRole": "starter",
            "dataSource": "system.firstAdditionalBattery.stateOfCharge",
            "capabilities": ["readSystemData"],
        }
        integrations = [dict(battery, id="starter"), dict(battery, id="auxiliary")]
        with self.assertRaisesRegex(ValueError, 'one overviewBattery'):
            MODULE.validate_integrations("partner", integrations)

    def test_partner_package_is_deterministic_and_has_install_layout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            compiled = root / "bluewater.json"
            compiled.write_text('{"name":"bluewater"}\n', encoding="utf-8")
            wasm = root / "wasm"
            (wasm / "partners" / "bluewater").mkdir(parents=True)
            (wasm / "branding.json").write_text('{"title":"Bluewater"}\n', encoding="utf-8")
            (wasm / "partners" / "bluewater" / "mark.svg").write_text(
                "<svg/>\n", encoding="utf-8")
            manifest = {
                "name": "bluewater",
                "version": "1.0.0",
                "model": 1,
                "minRequiredVersion": "1.3.20",
                "maxRequiredVersion": "1.999999",
            }
            first = root / "first.vgp"
            second = root / "second.vgp"
            MODULE.write_partner_package(first, compiled, manifest, wasm)
            MODULE.write_partner_package(second, compiled, manifest, wasm)

            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as package:
                self.assertEqual(package.namelist(), sorted([
                    "SHA256SUMS",
                    "gui-v2/bluewater.json",
                    "package.json",
                    "www/gui-v2/branding.json",
                    "www/gui-v2/partners/bluewater/mark.svg",
                ]))
                package_manifest = json.loads(package.read("package.json"))
                self.assertEqual(package_manifest["runtime"], "gui-v2/bluewater.json")
                self.assertEqual(package_manifest["formatVersion"], 1)


if __name__ == "__main__":
    unittest.main()
