# GUIv2 partner packs

Partner packs provide runtime branding and additive pages without modifying firmware-owned GUI files. They are trusted executable extensions and must be reviewed and distributed through an approved application/package channel.

Compile a schema version 2 pack from its root directory:

```sh
python3 ../../../tools/gui-v2-plugin-compiler.py --manifest manifest.json --output acme-marine.json
```

The manifest supports existing settings integrations and the `navigationPage` integration. A navigation page requires a stable `id`, `title`, icon, QML source, named placement, and optional numeric order. Its root object must be `PartnerNavigationPage`; GUIv2 injects `view`, `url`, `iconSource`, `title`, and the declared read-only data capability when it creates the page.

Brand colours are constrained to the allow-list implemented by `Theme`. In the canonical schema, `accent` is the single partner identity colour: GUIv2 applies it to ordinary gauge arcs, progress bars, selected navigation and controls, focus highlights, and other places that normally use Victron blue. GUIv2 derives the subdued/remainder colour by blending that accent towards each scheme's page background. `success`, `warning`, and `critical` remain separate semantic roles and must not be used as the ordinary accent. Values may be one colour for both schemes or an object containing `dark` and `light` values. Invalid or unknown runtime tokens reject the branding candidate and leave the Victron defaults active.

The optional `colors.tanks` object provides a constrained semantic palette for every GUIv2 fluid type: `fuel`, `freshWater`, `wasteWater`, `liveWell`, `oil`, `blackWater`, `gasoline`, `diesel`, `lpg`, `lng`, `hydraulicOil`, and `rawWater`. It contains matching `dark` and `light` maps. A partner may omit the whole tank palette, but when it is present the same roles must be supplied for both schemes. These colours identify fluid types consistently across the Levels and Brief pages; warning and critical gauge states override the tank colour.

Brand assets must resolve below the pack's own `qrc:/<pack-name>/` prefix. If zero or multiple enabled plug-ins provide branding, GUIv2 uses the standard Victron identity. Additive integrations from multiple plug-ins remain supported.

## Model 3 controlled page contributions

A canonical manifest with `model: 3` may combine Models 1 and 2 with three declarative integration types:

- `briefMetric` adds a standardized read-only metric to the existing Brief side panel (inline in portrait).
- `overviewEnergyNode` adds a source or load node to the native Overview flow layout.
- `overviewBattery` adds a compact starter or auxiliary battery row below the house battery. It shows one approved value (for example state of charge or voltage), does not participate in the energy-flow connectors, and leaves the information-rich house-battery widget at large size. A uniquely mapped row opens that physical device directly and suppresses its duplicate entry from the ordinary runtime Batteries list; system configuration continues to expose the device.

These integrations do not have a QML `source`. The partner declares a stable ID, short title, optional owned icon, ordering hint, semantic role, controlled `add`/`replace`/`hide` operation, unit, `readSystemData`, and an approved semantic `dataSource`. Overview nodes connect only to the battery or inverter/charger. GUIv2 owns rendering, geometry, connectors, light/dark styling, limits, and unavailable-value handling. Arbitrary D-Bus or MQTT paths and overlay coordinates are not accepted.

The current semantic keys cover the active house battery, aggregate solar power, aggregate AC/DC loads, explicitly mapped starter/auxiliary batteries, and explicitly mapped charging-source/consumer devices. A `batteryMappings` entry selects from `com.victronenergy.system/Batteries` by an exact, unique common name; an installer may also persist its resolved service ID and device instance. `deviceMappings.chargingSource` and `deviceMappings.consumer` similarly select an exact common name and approved D-Bus service type. GUIv2 derives the read-only power path for that type and displays the resolved device name, so the role names never appear as synthetic devices. Zero or ambiguous matches are unavailable and never fall back to an aggregate or unrelated device. New product signals and service types require an upstream semantic-key addition and review.

One cumulative `.vgp` can therefore install and roll back branding, partner pages, and Model 3 contributions atomically. Model 1 and Model 2 packs cannot declare Model 3 integration types.

The browser's pre-QML loader optionally reads a same-origin `branding.json`. It accepts a title, same-origin dark/light loading logos and favicon, and strict hex colours. The Victron mark outside the simulated GX display remains firmware-owned and cannot be replaced by a partner pack. A missing, slow, cross-origin, or invalid descriptor falls back to the standard loader after 250 ms.

See `examples/partner-packs/acme-marine` for a complete development example.
