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

- `briefMetric` adds a standardized read-only metric to the controlled Brief footer host.
- `overviewEnergyNode` adds a standardized Overview source or load reading.
- `overviewBattery` adds a starter or auxiliary battery reading from the first non-active system battery.

These integrations do not have a QML `source`. The partner declares a stable ID, short title, optional owned icon, ordering hint, presentation role, unit, `readSystemData`, and an approved semantic `dataSource`. GUIv2 owns rendering, light/dark styling, limits, and unavailable-value handling. Arbitrary D-Bus or MQTT paths are not accepted.

The current semantic keys cover the active house battery, aggregate solar power, aggregate AC/DC loads, and the first additional battery's state of charge, voltage, and power. New product signals require an upstream semantic-key addition and review.

One cumulative `.vgp` can therefore install and roll back branding, partner pages, and Model 3 contributions atomically. Model 1 and Model 2 packs cannot declare Model 3 integration types.

The browser's pre-QML loader optionally reads a same-origin `branding.json`. It accepts a title, same-origin dark/light loading logos and favicon, and strict hex colours. The Victron mark outside the simulated GX display remains firmware-owned and cannot be replaced by a partner pack. A missing, slow, cross-origin, or invalid descriptor falls back to the standard loader after 250 ms.

See `examples/partner-packs/acme-marine` for a complete development example.
