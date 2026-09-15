import json
import os
import sys
import subprocess
import argparse
import base64
import hashlib
import shutil
import xml.etree.ElementTree as ET
import re
import zipfile

os.environ.setdefault('SOURCE_DATE_EPOCH', '946684800')

SCHEMA_VERSION = 2
TANK_COLOR_TOKENS = {
    'fuel': 'color_fuel',
    'freshWater': 'color_freshWater',
    'wasteWater': 'color_wasteWater',
    'liveWell': 'color_liveWell',
    'oil': 'color_oil',
    'blackWater': 'color_blackWater',
    'gasoline': 'color_gasoline',
    'diesel': 'color_diesel',
    'lpg': 'color_lpg',
    'lng': 'color_lng',
    'hydraulicOil': 'color_hydraulicOil',
    'rawWater': 'color_rawWater',
}
INTEGRATION_TYPES = {
    "pluginSettingsPage": 1,
    "deviceListSettingsPage": 2,
    "navigationPage": 3,
    "quickAccessPane": 4,
    "quickAccessPaneCard": 5,
    "briefMetric": 6,
    "overviewEnergyNode": 7,
    "overviewBattery": 8,
    "briefLayout": 9,
}
NAVIGATION_PLACEMENTS = {
    "beforeBrief",
    "afterBrief",
    "beforeOverview",
    "afterOverview",
    "beforeNotifications",
    "afterNotifications",
    "beforeSettings",
}

POSITION_ANCHORS = {
    'brief': 'Brief',
    'overview': 'Overview',
    'notifications': 'Notifications',
    'settings': 'Settings',
}

ALLOWED_CAPABILITIES = {
    'readSystemData',
}

MODEL3_INTEGRATION_TYPES = {
    'briefMetric',
    'overviewEnergyNode',
    'overviewBattery',
    'briefLayout',
}
MODEL3_DATA_SOURCES = {
    'system.houseBattery.stateOfCharge': '%',
    'system.houseBattery.voltage': 'V',
    'system.houseBattery.power': 'W',
    'system.solar.power': 'W',
    'system.acLoad.power': 'W',
    'system.dcLoad.power': 'W',
    'system.tank.freshWater.level': '%',
    'system.tank.fuel.level': '%',
    'system.tank.wasteWater.level': '%',
    'system.gxRelay.1.state': '',
    'system.firstAdditionalBattery.stateOfCharge': '%',
    'system.firstAdditionalBattery.voltage': 'V',
    'system.firstAdditionalBattery.power': 'W',
    'system.battery.starter.stateOfCharge': '%',
    'system.battery.starter.voltage': 'V',
    'system.battery.starter.power': 'W',
    'system.battery.auxiliary.stateOfCharge': '%',
    'system.battery.auxiliary.voltage': 'V',
    'system.battery.auxiliary.power': 'W',
    'system.device.chargingSource.power': 'W',
    'system.device.consumer.power': 'W',
}
MODEL3_UNITS = {'%', 'V', 'W', 'A', ''}
DEVICE_MAPPING_PATHS = {
    'chargingSource': {
        'alternator': '/Dc/0/Power',
        'solarcharger': '/Yield/Power',
        'charger': '/Dc/0/Power',
        'dcsource': '/Dc/0/Power',
    },
    'consumer': {
        'acload': '/Ac/Power',
        'heatpump': '/Ac/Power',
        'dcload': '/Dc/0/Power',
    },
}

# These service types already contribute to native Overview widgets or load
# aggregates. Adding them as separate flow nodes would represent the same
# physical energy twice. New reviewed service types may be added without being
# placed in this set when GUIv2 has no native representation for them.
NATIVE_OVERVIEW_DEVICE_TYPES = {
    'alternator', 'solarcharger', 'charger', 'dcsource',
    'acload', 'heatpump', 'dcload',
}

def collect_filenames(directory, suffix):
    files = []
    for root, dirnames, filenames in os.walk(directory):
        dirnames[:] = [
            dirname for dirname in dirnames
            if dirname not in {'__pycache__', 'dist', 'docs', 'expected', 'fixtures', 'wasm-bootstrap'}
        ]
        for filename in filenames:
            if filename.endswith(suffix):
                path = os.path.relpath(os.path.join(root, filename), directory)
                files.append(path.replace(os.sep, '/'))
    return sorted(files)

def fail(message):
    raise ValueError(message)

def require_string(value, field):
    if not isinstance(value, str) or not value.strip():
        fail(f'"{field}" must be a non-empty string')
    return value.strip()

def validate_package_name(name):
    name = require_string(name, 'name')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', name):
        fail('"name" may only contain letters, numbers, dot, underscore, and hyphen')
    return name

def resource_url(name, path, field):
    path = require_string(path, field)
    if path.startswith('qrc:/'):
        expected_prefix = f'qrc:/{name}/'
        if not path.startswith(expected_prefix):
            fail(f'"{field}" must refer to a resource owned by {name}')
        relative = path[len(expected_prefix):]
    else:
        relative = path.replace('\\', '/').lstrip('./')
        path = f'qrc:/{name}/{relative}'
    if relative.startswith('../') or '/..' in relative:
        fail(f'"{field}" must remain inside the partner pack')
    if not os.path.isfile(relative):
        fail(f'file referenced by "{field}" does not exist: {relative}')
    return path

def validate_branding(name, manifest_branding):
    if manifest_branding is None:
        return {}
    if not isinstance(manifest_branding, dict):
        fail('"branding" must be an object')

    definition = manifest_branding.get('definition')
    if definition:
        definition_path = require_string(definition, 'branding.definition')
        if definition_path.startswith('qrc:/'):
            expected_prefix = f'qrc:/{name}/'
            if not definition_path.startswith(expected_prefix):
                fail(f'"branding.definition" must refer to a resource owned by {name}')
            definition_path = definition_path[len(expected_prefix):]
        definition_path = definition_path.replace('\\', '/').lstrip('./')
        if not os.path.isfile(definition_path):
            fail(f'branding definition does not exist: {definition_path}')
        with open(definition_path, encoding='utf-8') as file:
            branding = json.load(file)
    else:
        branding = dict(manifest_branding)

    if not isinstance(branding, dict):
        fail('branding definition must contain a JSON object')
    for field in ('logo', 'logoDark', 'logoLight', 'splashLogo'):
        if branding.get(field):
            branding[field] = resource_url(name, branding[field], f'branding.{field}')
    colors = branding.get('colors', {})
    if not isinstance(colors, dict):
        fail('"branding.colors" must be an object')
    return branding

def normalize_maximum_version(value):
    if not isinstance(value, str):
        return ''
    parts = value.strip().split('.')
    return '.'.join('999999' if part.lower() in ('x', '*') else part for part in parts)

def semantic_theme_colors(colors):
    if not isinstance(colors, dict):
        fail('"branding.colors" must be an object')
    dark = colors.get('dark', {})
    light = colors.get('light', {})
    if not isinstance(dark, dict) or not isinstance(light, dict):
        fail('"branding.colors.dark" and "branding.colors.light" must be objects')

    mapped = {}

    def blend(foreground, background, foreground_weight=0.36):
        """Return a subdued accent blended towards the scheme background."""
        if not (isinstance(foreground, str) and isinstance(background, str)):
            return foreground
        if not re.fullmatch(r'#[0-9A-Fa-f]{6}', foreground) \
                or not re.fullmatch(r'#[0-9A-Fa-f]{6}', background):
            return foreground
        fg = tuple(int(foreground[index:index + 2], 16) for index in (1, 3, 5))
        bg = tuple(int(background[index:index + 2], 16) for index in (1, 3, 5))
        mixed = tuple(round(foreground_weight * f + (1.0 - foreground_weight) * b)
            for f, b in zip(fg, bg))
        return '#{:02X}{:02X}{:02X}'.format(*mixed)
    def schemes(tokens, semantic):
        values = {}
        if dark.get(semantic):
            values['dark'] = dark[semantic]
        if light.get(semantic):
            values['light'] = light[semantic]
        if values:
            for token in ([tokens] if isinstance(tokens, str) else tokens):
                mapped[token] = values

    schemes('color_page_background', 'pageBackground')
    schemes(('color_background_secondary', 'color_card_background',
        'color_listItem_background', 'color_overviewPage_widget_background'),
        'cardBackground')
    schemes('color_navigationBar_background', 'navigationBackground')
    schemes('color_font_primary', 'primaryText')
    schemes(('color_font_secondary', 'color_listItem_secondaryText',
        'color_navigationBar_button_off'), 'secondaryText')
    schemes(('color_card_separator', 'color_separator', 'color_listItem_separator',
        'color_modalDialog_border'), 'divider')
    if colors.get('primary'):
        mapped['color_button'] = colors['primary']
    if colors.get('accent'):
        accent = colors['accent']
        for token in (
                'color_brand_accent', 'color_blue', 'color_ok',
                'color_navigationBar_button_on', 'color_focus_highlight',
                'color_splash_logo_icon', 'color_splash_logo_text',
                'color_button_on_background', 'color_droopGraph_gradient_centre',
                'color_overviewPage_widget_battery_background',
                'color_overviewPage_widget_border',
                'color_overviewPage_widget_solar_graph_bar',
                'color_radioButton_indicator_on',
                'color_settings_breadcrumb_background_top_page',
                'color_switch_groove_on',
                'color_toastNotification_highlight_informative'):
            mapped[token] = accent
        muted = {}
        if dark.get('pageBackground'):
            muted['dark'] = blend(accent, dark['pageBackground'])
        if light.get('pageBackground'):
            muted['light'] = blend(accent, light['pageBackground'])
        if muted:
            mapped['color_brand_accent_muted'] = muted
            mapped['color_darkOk'] = muted
    for semantic, token in (
            ('success', 'color_success'),
            ('warning', 'color_warning'),
            ('critical', 'color_critical')):
        if colors.get(semantic):
            mapped[token] = colors[semantic]

    tanks = colors.get('tanks', {})
    if not isinstance(tanks, dict):
        fail('"branding.colors.tanks" must be an object')
    if tanks:
        tank_schemes = {}
        for scheme in ('dark', 'light'):
            values = tanks.get(scheme)
            if not isinstance(values, dict):
                fail(f'"branding.colors.tanks.{scheme}" must be an object')
            unknown = set(values).difference(TANK_COLOR_TOKENS)
            if unknown:
                fail(f'unsupported tank colour roles: {", ".join(sorted(unknown))}')
            tank_schemes[scheme] = values
        if set(tank_schemes['dark']) != set(tank_schemes['light']):
            fail('dark and light tank colour roles must match')
        for semantic, dark_value in tank_schemes['dark'].items():
            mapped[TANK_COLOR_TOKENS[semantic]] = {
                'dark': dark_value,
                'light': tank_schemes['light'][semantic],
            }
    return mapped

def validate_canonical_branding(name, display_name, definition_path):
    definition_path = require_string(definition_path, 'branding')
    if not os.path.isfile(definition_path):
        fail(f'branding definition does not exist: {definition_path}')
    with open(definition_path, encoding='utf-8') as file:
        source = json.load(file)
    if not isinstance(source, dict):
        fail('branding definition must contain a JSON object')
    logos = source.get('logos', {})
    if not isinstance(logos, dict):
        fail('"branding.logos" must be an object')

    branding = {
        'id': name,
        'displayName': source.get('name') or display_name,
        'attribution': source.get('attribution', ''),
        'colors': semantic_theme_colors(source.get('colors', {})),
    }
    for source_field, runtime_field in (
            ('dark', 'logoDark'), ('light', 'logoLight'), ('splash', 'splashLogo')):
        if logos.get(source_field):
            branding[runtime_field] = resource_url(name, logos[source_field],
                f'branding.logos.{source_field}')
    return branding, source

def canonical_placement(position):
    if position is None:
        return 'beforeNotifications'
    if not isinstance(position, dict):
        fail('navigation position must be an object')
    for direction in ('before', 'after'):
        if position.get(direction):
            anchor = POSITION_ANCHORS.get(str(position[direction]).lower())
            if not anchor:
                fail(f'unsupported navigation position anchor: {position[direction]}')
            placement = direction + anchor
            if placement not in NAVIGATION_PLACEMENTS:
                fail(f'unsupported navigation placement: {placement}')
            return placement
    fallback = position.get('fallback', 'beforeSettings')
    if fallback not in NAVIGATION_PLACEMENTS:
        fail(f'invalid navigation fallback placement: {fallback}')
    return fallback

def normalize_canonical_integrations(integrations):
    normalized = []
    for integration in integrations:
        item = dict(integration)
        if item.get('type') == 'navigationPage':
            item['placement'] = canonical_placement(item.pop('position', None))
        normalized.append(item)
    return normalized

def write_wasm_bootstrap(directory, name, canonical_branding):
    browser = canonical_branding.get('browser', {})
    logos = canonical_branding.get('logos', {})
    colors = canonical_branding.get('colors', {})
    splash = canonical_branding.get('splash', {})
    dark = colors.get('dark', {})
    light = colors.get('light', {})
    required_assets = {
        'logoDark': logos.get('dark'),
        'logoLight': logos.get('light'),
        'splashLogo': logos.get('splash'),
        'favicon': logos.get('browser'),
    }
    for field, source in required_assets.items():
        if not source:
            fail(f'canonical branding requires logos.{field[4:].lower() if field.startswith("logo") else "browser" if field == "favicon" else "splash"} for WASM bootstrap output')
        if not os.path.isfile(source):
            fail(f'WASM bootstrap asset does not exist: {source}')

    asset_urls = {}
    for field, source in required_assets.items():
        asset_relative = f'partners/{name}/{source}'
        destination = os.path.join(directory, asset_relative)
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        shutil.copy2(source, destination)
        asset_urls[field] = asset_relative
    descriptor = {
        'title': browser.get('title') or canonical_branding.get('name') or name,
        **asset_urls,
        'colors': {
            'dark': {
                'background': splash.get('backgroundDark') or dark.get('pageBackground'),
                'text': dark.get('primaryText'),
                'muted': dark.get('secondaryText'),
                'accent': colors.get('accent'),
            },
            'light': {
                'background': splash.get('backgroundLight') or light.get('pageBackground'),
                'text': light.get('primaryText'),
                'muted': light.get('secondaryText'),
                'accent': colors.get('accent'),
            },
        },
    }
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, 'branding.json'), 'w', encoding='utf-8') as file:
        json.dump(descriptor, file, indent=2, sort_keys=True)
        file.write('\n')

def write_partner_package(filename, compiled_filename, manifest, wasm_bootstrap_directory):
    """Write the deterministic, transportable partner-package archive."""
    if not manifest:
        fail('--package-output requires a schema v2 manifest')
    if not os.path.isfile(compiled_filename):
        fail(f'compiled runtime bundle does not exist: {compiled_filename}')

    def read_bytes(path):
        with open(path, 'rb') as source:
            return source.read()

    runtime_path = f"gui-v2/{manifest['name']}.json"
    payloads = {
        runtime_path: read_bytes(compiled_filename),
    }
    if wasm_bootstrap_directory:
        for root, _, filenames in os.walk(wasm_bootstrap_directory):
            for item in sorted(filenames):
                source = os.path.join(root, item)
                relative = os.path.relpath(source, wasm_bootstrap_directory).replace(os.sep, '/')
                payloads[f'www/gui-v2/{relative}'] = read_bytes(source)

    package_manifest = {
        'format': 'gui-v2-partner-package',
        'formatVersion': 1,
        'id': manifest['name'],
        'version': manifest['version'],
        'model': manifest.get('model'),
        'compatibleGuiV2': {
            'minimum': manifest['minRequiredVersion'],
            'maximum': manifest['maxRequiredVersion'],
        },
        'runtime': runtime_path,
        'wasmBootstrap': 'www/gui-v2/branding.json' if wasm_bootstrap_directory else '',
    }
    payloads['package.json'] = (
        json.dumps(package_manifest, indent=2, sort_keys=True) + '\n').encode('utf-8')
    checksums = ''.join(
        f"{hashlib.sha256(payloads[path]).hexdigest()}  {path}\n"
        for path in sorted(payloads)
    )
    payloads['SHA256SUMS'] = checksums.encode('ascii')

    os.makedirs(os.path.dirname(os.path.abspath(filename)), exist_ok=True)
    with zipfile.ZipFile(filename, 'w', compression=zipfile.ZIP_DEFLATED,
            compresslevel=9) as archive:
        for path in sorted(payloads):
            info = zipfile.ZipInfo(path, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, payloads[path], compress_type=zipfile.ZIP_DEFLATED,
                compresslevel=9)

def validate_battery_mappings(value):
    if value is None:
        return {}
    if not isinstance(value, dict):
        fail('"batteryMappings" must be an object')
    unknown_roles = sorted(set(value) - {'starter', 'auxiliary'})
    if unknown_roles:
        fail('batteryMappings has unsupported roles: ' + ', '.join(unknown_roles))
    result = {}
    for role, selector in value.items():
        if not isinstance(selector, dict):
            fail(f'batteryMappings.{role} must be an object')
        unknown_fields = sorted(set(selector) - {'name', 'serviceId', 'deviceInstance'})
        if unknown_fields:
            fail(f'batteryMappings.{role} has unsupported fields: ' + ', '.join(unknown_fields))
        common_name = selector.get('name')
        service_id = selector.get('serviceId')
        device_instance = selector.get('deviceInstance')
        if common_name is None and service_id is None and device_instance is None:
            fail(f'batteryMappings.{role} must provide name, serviceId or deviceInstance')
        compiled = {}
        if common_name is not None:
            compiled['name'] = require_string(common_name, f'batteryMappings.{role}.name')
        if service_id is not None:
            service_id = require_string(service_id, f'batteryMappings.{role}.serviceId')
            if not re.fullmatch(r'com\.victronenergy\.[A-Za-z0-9_.-]+', service_id):
                fail(f'batteryMappings.{role}.serviceId is not a Victron D-Bus service id')
            compiled['serviceId'] = service_id
        if device_instance is not None:
            if not isinstance(device_instance, int) or isinstance(device_instance, bool) or device_instance < 0:
                fail(f'batteryMappings.{role}.deviceInstance must be a non-negative integer')
            compiled['deviceInstance'] = device_instance
        result[role] = compiled
    return result


def validate_device_mappings(value):
    if value is None:
        return {}
    if not isinstance(value, dict):
        fail('"deviceMappings" must be an object')
    unknown_roles = sorted(set(value) - set(DEVICE_MAPPING_PATHS))
    if unknown_roles:
        fail('deviceMappings has unsupported roles: ' + ', '.join(unknown_roles))
    result = {}
    for role, selector in value.items():
        if not isinstance(selector, dict):
            fail(f'deviceMappings.{role} must be an object')
        unknown_fields = sorted(set(selector) - {'name', 'serviceType', 'serviceId', 'deviceInstance'})
        if unknown_fields:
            fail(f'deviceMappings.{role} has unsupported fields: ' + ', '.join(unknown_fields))
        common_name = require_string(selector.get('name'), f'deviceMappings.{role}.name')
        service_type = require_string(selector.get('serviceType'), f'deviceMappings.{role}.serviceType')
        if service_type not in DEVICE_MAPPING_PATHS[role]:
            fail(f'deviceMappings.{role}.serviceType is not supported for this role')
        compiled = {'name': common_name, 'serviceType': service_type}
        service_id = selector.get('serviceId')
        if service_id is not None:
            service_id = require_string(service_id, f'deviceMappings.{role}.serviceId')
            if not re.fullmatch(rf'com\.victronenergy\.{re.escape(service_type)}\.[A-Za-z0-9_.-]+', service_id):
                fail(f'deviceMappings.{role}.serviceId does not match serviceType')
            compiled['serviceId'] = service_id
        device_instance = selector.get('deviceInstance')
        if device_instance is not None:
            if not isinstance(device_instance, int) or isinstance(device_instance, bool) or device_instance < 0:
                fail(f'deviceMappings.{role}.deviceInstance must be a non-negative integer')
            compiled['deviceInstance'] = device_instance
        result[role] = {
            'selector': compiled,
            'measurementPath': DEVICE_MAPPING_PATHS[role][service_type],
        }
    return result


def validate_data_bindings(value, battery_mappings, device_mappings, context):
    if value is None:
        return {}
    if not isinstance(value, dict):
        fail(f'"{context}" must be an object')
    if len(value) > 32:
        fail(f'"{context}" supports at most 32 bindings')
    result = {}
    for binding_id, binding in value.items():
        if not re.fullmatch(r'[a-z][A-Za-z0-9]*', binding_id):
            fail(f'{context} has invalid binding id: {binding_id}')
        if not isinstance(binding, dict):
            fail(f'{context}.{binding_id} must be an object')
        unknown_fields = sorted(set(binding) - {'dataSource', 'unit', 'demoName', 'demoValue'})
        if unknown_fields:
            fail(f'{context}.{binding_id} has unsupported fields: ' + ', '.join(unknown_fields))
        data_source = require_string(binding.get('dataSource'), f'{context}.{binding_id}.dataSource')
        if data_source not in MODEL3_DATA_SOURCES:
            fail(f'{context}.{binding_id} has unsupported dataSource: {data_source}')
        unit = binding.get('unit', MODEL3_DATA_SOURCES[data_source])
        if unit not in MODEL3_UNITS:
            fail(f'{context}.{binding_id} has unsupported unit: {unit}')
        compiled = {'dataSource': data_source, 'unit': unit}
        if 'demoValue' in binding:
            demo_value = binding['demoValue']
            if not isinstance(demo_value, (int, float)) or isinstance(demo_value, bool):
                fail(f'{context}.{binding_id}.demoValue must be a number')
            compiled['demoValue'] = demo_value
            compiled['demoName'] = require_string(
                binding.get('demoName'), f'{context}.{binding_id}.demoName')
        elif 'demoName' in binding:
            fail(f'{context}.{binding_id}.demoName requires demoValue')
        if data_source.startswith('system.battery.'):
            battery_role = data_source.split('.')[2]
            if battery_role not in battery_mappings:
                fail(f'{context}.{binding_id} requires batteryMappings.{battery_role}')
            compiled['batterySelector'] = battery_mappings[battery_role]
        elif data_source.startswith('system.device.'):
            device_role = data_source.split('.')[2]
            if device_role not in device_mappings:
                fail(f'{context}.{binding_id} requires deviceMappings.{device_role}')
            compiled['deviceSelector'] = device_mappings[device_role]['selector']
            compiled['measurementPath'] = device_mappings[device_role]['measurementPath']
        result[binding_id] = compiled
    return result


def validate_integrations(name, integrations, battery_mappings=None, device_mappings=None):
    battery_mappings = battery_mappings or {}
    device_mappings = device_mappings or {}
    if not isinstance(integrations, list):
        fail('"integrations" must be an array')
    if sum(1 for integration in integrations
            if isinstance(integration, dict) and integration.get('type') == 'overviewBattery') > 1:
        fail('Model 3 supports one overviewBattery (the secondary battery)')
    if sum(1 for integration in integrations
            if isinstance(integration, dict) and integration.get('type') == 'briefLayout') > 1:
        fail('Model 3 supports one briefLayout policy')
    result = []
    integration_ids = set()
    for index, integration in enumerate(integrations):
        if not isinstance(integration, dict):
            fail(f'integration {index} must be an object')
        integration_type = integration.get('type')
        if integration_type not in INTEGRATION_TYPES:
            fail(f'integration {index} has unsupported type: {integration_type}')

        compiled = dict(integration)
        compiled['type'] = integration_type
        if integration_type not in MODEL3_INTEGRATION_TYPES:
            compiled['url'] = resource_url(name,
                integration.get('url', integration.get('source')),
                f'integrations[{index}].url')
            compiled.pop('source', None)

        identified_integration = integration_type in ('navigationPage', 'quickAccessPane') \
            or integration_type in MODEL3_INTEGRATION_TYPES
        if identified_integration:
            integration_id = require_string(integration.get('id'), f'integrations[{index}].id')
            if integration_id in integration_ids:
                fail(f'duplicate integration id: {integration_id}')
            integration_ids.add(integration_id)
            compiled['id'] = integration_id
            operation = integration.get('operation', 'add') if integration_type in MODEL3_INTEGRATION_TYPES else 'add'
            if operation not in ('add', 'replace', 'hide'):
                fail(f'integrations[{index}].operation must be add, replace or hide')
            if integration_type == 'overviewBattery' and operation != 'add':
                fail(f'integrations[{index}] overviewBattery only supports operation add')
            if integration_type in MODEL3_INTEGRATION_TYPES:
                compiled['operation'] = operation
            if operation == 'hide':
                compiled['title'] = integration.get('title', '')
            else:
                compiled['title'] = require_string(integration.get('title'), f'integrations[{index}].title')
            order = integration.get('order', 0)
            if not isinstance(order, int) or isinstance(order, bool):
                fail(f'integrations[{index}].order must be an integer')
            compiled['order'] = order
            capabilities = integration.get('capabilities', [])
            if not isinstance(capabilities, list) or any(
                    not isinstance(capability, str) for capability in capabilities):
                fail(f'integrations[{index}].capabilities must be an array of strings')
            unknown_capabilities = sorted(set(capabilities) - ALLOWED_CAPABILITIES)
            if unknown_capabilities:
                fail(f'integrations[{index}] requests unsupported capabilities: '
                    + ', '.join(unknown_capabilities))
            if len(capabilities) != len(set(capabilities)):
                fail(f'integrations[{index}].capabilities contains duplicates')
            if integration_type in MODEL3_INTEGRATION_TYPES and operation != 'hide' and 'readSystemData' not in capabilities:
                fail(f'integrations[{index}] must request readSystemData')
            compiled['capabilities'] = capabilities
            if integration.get('icon'):
                compiled['icon'] = resource_url(name, integration['icon'], f'integrations[{index}].icon')

        if integration_type in ('navigationPage', 'quickAccessPane'):
            compiled['icon'] = resource_url(name, integration.get('icon'), f'integrations[{index}].icon')
            if integration.get('iconActive'):
                compiled['iconActive'] = resource_url(
                    name, integration['iconActive'], f'integrations[{index}].iconActive')
            if 'dataBindings' in integration:
                compiled['dataBindings'] = validate_data_bindings(
                    integration.get('dataBindings'), battery_mappings, device_mappings,
                    f'integrations[{index}].dataBindings')
        if integration_type == 'navigationPage':
            placement = integration.get('placement', 'beforeNotifications')
            if placement not in NAVIGATION_PLACEMENTS:
                fail(f'invalid navigation placement: {placement}')
            compiled['placement'] = placement
        elif integration_type == 'briefLayout':
            if operation != 'add':
                fail(f'integrations[{index}] briefLayout only supports operation add')
            mode = integration.get('mode', 'partnerDefault')
            if mode not in ('user', 'partnerDefault', 'partnerLocked'):
                fail(f'integrations[{index}].mode must be user, partnerDefault or partnerLocked')
            gauges = integration.get('centerGauges', [])
            if not isinstance(gauges, list) or not 1 <= len(gauges) <= 4:
                fail(f'integrations[{index}].centerGauges must contain 1 to 4 gauges')
            compiled_gauges = []
            allowed_gauges = {
                'system.houseBattery.stateOfCharge',
                'system.battery.starter.stateOfCharge',
                'system.battery.auxiliary.stateOfCharge',
                'system.tank.freshWater.level',
                'system.tank.fuel.level',
                'system.tank.wasteWater.level',
            }
            for gauge_index, gauge in enumerate(gauges):
                if not isinstance(gauge, dict) or set(gauge) != {'dataSource'}:
                    fail(f'integrations[{index}].centerGauges[{gauge_index}] must only contain dataSource')
                data_source = require_string(gauge.get('dataSource'),
                    f'integrations[{index}].centerGauges[{gauge_index}].dataSource')
                if data_source not in allowed_gauges:
                    fail(f'integrations[{index}].centerGauges[{gauge_index}] has unsupported dataSource')
                compiled_gauge = {'dataSource': data_source}
                if data_source.startswith('system.battery.'):
                    role = data_source.split('.')[2]
                    if role not in battery_mappings:
                        fail(f'integrations[{index}].centerGauges[{gauge_index}] requires batteryMappings.{role}')
                    compiled_gauge['batterySelector'] = battery_mappings[role]
                compiled_gauges.append(compiled_gauge)
            center_detail = integration.get('centerDetail', 'system.houseBattery.stateOfCharge')
            if center_detail not in {
                    'system.houseBattery.stateOfCharge',
                    'system.battery.starter.stateOfCharge',
                    'system.battery.auxiliary.stateOfCharge'}:
                fail(f'integrations[{index}].centerDetail has unsupported dataSource')
            compiled['mode'] = mode
            compiled['centerGauges'] = compiled_gauges
            compiled['centerDetail'] = {'dataSource': center_detail}
            if center_detail.startswith('system.battery.'):
                role = center_detail.split('.')[2]
                if role not in battery_mappings:
                    fail(f'integrations[{index}].centerDetail requires batteryMappings.{role}')
                compiled['centerDetail']['batterySelector'] = battery_mappings[role]
        elif integration_type in MODEL3_INTEGRATION_TYPES:
            if operation != 'hide':
                data_source = require_string(integration.get('dataSource'), f'integrations[{index}].dataSource')
                if data_source not in MODEL3_DATA_SOURCES:
                    fail(f'integrations[{index}] has unsupported dataSource: {data_source}')
                compiled['dataSource'] = data_source
                unit = integration.get('unit', MODEL3_DATA_SOURCES[data_source])
                if unit not in MODEL3_UNITS:
                    fail(f'integrations[{index}] has unsupported unit: {unit}')
                compiled['unit'] = unit
                if data_source.startswith('system.battery.'):
                    battery_role = data_source.split('.')[2]
                    if battery_role not in battery_mappings:
                        fail(f'integrations[{index}] requires batteryMappings.{battery_role}')
                    compiled['batterySelector'] = battery_mappings[battery_role]
                if data_source.startswith('system.device.'):
                    device_role = data_source.split('.')[2]
                    if device_role not in device_mappings:
                        fail(f'integrations[{index}] requires deviceMappings.{device_role}')
                    expected_role = 'source' if device_role == 'chargingSource' else 'load'
                    if integration_type == 'overviewEnergyNode' and integration.get('role') != expected_role:
                        fail(f'integrations[{index}] role does not match mapped device role')
                    compiled['deviceSelector'] = device_mappings[device_role]['selector']
                    compiled['measurementPath'] = device_mappings[device_role]['measurementPath']
            if integration_type == 'briefMetric':
                placement = integration.get('placement', 'sidePanel')
                if placement != 'sidePanel':
                    fail(f'integrations[{index}] has unsupported Brief placement: {placement}')
                compiled['placement'] = placement
                if operation in ('replace', 'hide'):
                    target = integration.get('target')
                    if target not in ('solar', 'generator', 'acInput', 'dcInput', 'acLoads', 'dcLoads'):
                        fail(f'integrations[{index}] has unsupported Brief target: {target}')
                    compiled['target'] = target
            elif integration_type == 'overviewEnergyNode':
                role = integration.get('role')
                if role not in ('source', 'load'):
                    fail(f'integrations[{index}].role must be source or load')
                compiled['role'] = role
                compiled['placement'] = role
                connection_target = integration.get('connectionTarget', 'battery')
                if connection_target not in ('battery', 'inverterCharger'):
                    fail(f'integrations[{index}].connectionTarget must be battery or inverterCharger')
                compiled['connectionTarget'] = connection_target
                demo_only = integration.get('demoOnly', False)
                if not isinstance(demo_only, bool):
                    fail(f'integrations[{index}].demoOnly must be a boolean')
                if demo_only:
                    demo_value = integration.get('demoValue')
                    if not isinstance(demo_value, (int, float)) or isinstance(demo_value, bool):
                        fail(f'integrations[{index}].demoValue must be a number for a demo-only node')
                    compiled['demoOnly'] = True
                    compiled['demoValue'] = demo_value
                    compiled['demoName'] = require_string(
                        integration.get('demoName'), f'integrations[{index}].demoName')
                elif operation == 'add' and data_source.startswith('system.device.'):
                    device_role = data_source.split('.')[2]
                    service_type = device_mappings[device_role]['selector']['serviceType']
                    if service_type in NATIVE_OVERVIEW_DEVICE_TYPES:
                        fail(f'integrations[{index}] would duplicate a native Overview service type: '
                            f'{service_type}')
                if operation in ('replace', 'hide'):
                    target = integration.get('target')
                    if target not in ('solar', 'acLoads', 'dcLoads'):
                        fail(f'integrations[{index}] has unsupported Overview target: {target}')
                    compiled['target'] = target
            else:
                battery_role = integration.get('batteryRole', 'auxiliary')
                if battery_role not in ('starter', 'auxiliary'):
                    fail(f'integrations[{index}].batteryRole must be starter or auxiliary')
                expected_prefixes = (
                    'system.firstAdditionalBattery.',
                    f'system.battery.{battery_role}.',
                )
                if not data_source.startswith(expected_prefixes):
                    fail(f'integrations[{index}] overviewBattery data does not match batteryRole')
                compiled['batteryRole'] = battery_role
                compiled['placement'] = 'battery'
        result.append(compiled)
    return result

def load_manifest(filename):
    with open(filename, encoding='utf-8') as file:
        manifest = json.load(file)
    if not isinstance(manifest, dict):
        fail('manifest must contain a JSON object')
    if manifest.get('schemaVersion') != SCHEMA_VERSION:
        fail(f'"schemaVersion" must be {SCHEMA_VERSION}')
    canonical = isinstance(manifest.get('branding'), str)
    name = validate_package_name(manifest.get('id') if canonical else manifest.get('name'))
    version = require_string(manifest.get('version'), 'version')
    canonical_branding = None
    if canonical:
        model = manifest.get('model')
        if model not in (1, 2, 3):
            fail('"model" must be 1, 2 or 3')
        if model == 1 and manifest.get('integrations'):
            fail('Model 1 partner packs cannot declare integrations')
        if model < 3 and any(integration.get('type') in MODEL3_INTEGRATION_TYPES
                for integration in manifest.get('integrations', [])):
            fail('Model 3 integrations require "model": 3')
        source_integrations = normalize_canonical_integrations(manifest.get('integrations', []))
        battery_mappings = validate_battery_mappings(manifest.get('batteryMappings'))
        device_mappings = validate_device_mappings(manifest.get('deviceMappings'))
        branding, canonical_branding = validate_canonical_branding(
            name, require_string(manifest.get('name'), 'name'), manifest['branding'])
        compatibility = manifest.get('compatibleGuiV2', {})
        if not isinstance(compatibility, dict):
            fail('"compatibleGuiV2" must be an object')
        minimum = compatibility.get('minimum', '')
        maximum = normalize_maximum_version(compatibility.get('maximum', ''))
    else:
        source_integrations = manifest.get('integrations', [])
        branding = validate_branding(name, manifest.get('branding'))
        minimum = manifest.get('minRequiredVersion', '')
        maximum = manifest.get('maxRequiredVersion', '')
        battery_mappings = {}
        device_mappings = {}
    integrations = validate_integrations(name, source_integrations, battery_mappings, device_mappings)
    if not integrations and not branding:
        fail('partner pack must contain branding or at least one integration')
    return {
        'schemaVersion': SCHEMA_VERSION,
        'name': name,
        'version': version,
        'minRequiredVersion': minimum,
        'maxRequiredVersion': maximum,
        'branding': branding,
        'integrations': integrations,
        'canonicalBranding': canonical_branding,
        'model': model if canonical else None,
    }

def run_lupdate(qmlFiles, tsFiles, name):
    cmd = ['lupdate']
    cmd.extend(qmlFiles)
    if len(tsFiles) > 0:
        cmd.extend(['-ts'])
        for tsFile in tsFiles:
            cmd.extend([tsFile])
    else:
        defaultTsName = "" + name + "_en.ts"
        cmd.extend(['-ts', defaultTsName])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        if result.stdout:
            print("    lupdate output:", result.stdout)
        if result.stderr:
            print("    lupdate stderr:", result.stderr)
    except subprocess.CalledProcessError as e:
        print(f"    lupdate returncode: {e.returncode}")
        print("    lupdate error:", e.stderr, file=sys.stderr)

def run_lrelease(tsFiles, name):
    if len(tsFiles) == 0:
        tsFiles.append("" + name + "_en.ts")
    for filename in tsFiles:
        qmFile = filename[:-2] + "qm"
        cmd = ['lrelease']
        cmd.extend([filename])
        cmd.extend(['-idbased'])
        cmd.extend(['-qm', qmFile])
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            if result.stdout:
                print("    lrelease output:", result.stdout)
            if result.stderr:
                print("    lrelease stderr:", result.stderr)
        except subprocess.CalledProcessError as e:
            print(f"    lrelease returncode: {e.returncode}")
            print("    lrelease error:", e.stderr, file=sys.stderr)

def write_qrc(qmlFiles, qmFiles, imageFiles, name):
    allFiles = qmlFiles + qmFiles + imageFiles
    contents = "<RCC>\n<qresource prefix=\"/" + name + "\">\n"
    for filename in allFiles:
        contents += "<file>" + filename + "</file>\n"
    contents += "</qresource>\n</RCC>\n"
    try:
        filename = "" + name + ".qrc"
        with open(filename, 'w') as file:
            file.write(contents)
    except IOError as e:
        print(f"    Error writing to file: {e}")

def run_rcc(name):
    if shutil.which('rcc'):
        rccPath = 'rcc'
    else:
        lreleasePath = shutil.which('lrelease')
        candidates = []
        if lreleasePath:
            qt_root = os.path.dirname(os.path.dirname(os.path.realpath(lreleasePath)))
            candidates.append(os.path.join(qt_root, 'libexec', 'rcc'))
        candidates.extend(['/usr/lib/qt6/libexec/rcc', '/usr/libexec/rcc'])
        rccPath = next((path for path in candidates if os.path.isfile(path)), None)
        if not rccPath:
            raise RuntimeError('rcc not found; install Qt tools or pass an existing file with --rcc')

    qrcFile = "" + name + ".qrc"
    rccFile = "" + name + ".rcc"
    cmd = [rccPath]
    cmd.extend(['-binary'])
    cmd.extend(['-compress-algo', 'zlib'])
    cmd.extend(['-o', rccFile])
    cmd.extend([qrcFile])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        if result.stdout:
            print("    rcc output:", result.stdout)
        if result.stderr:
            print("    rcc stderr:", result.stderr)
        return rccFile
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f'rcc failed: {e.stderr.strip()}') from e
    except FileNotFoundError:
        raise RuntimeError('rcc not found; install Qt tools or pass an existing file with --rcc')

def b64_encode_rcc(rccFile):
    try:
        with open(rccFile, 'rb') as file:
            data = file.read()
            if not data:
                fail(f'resource file is empty: {rccFile}')
            base64data = base64.b64encode(data)
            return base64data.decode('utf-8')
    except FileNotFoundError as error:
        raise ValueError(f'cannot open resource file: {rccFile}') from error

def write_compiled_json(name, version, minRequiredVersion, maxRequiredVersion, translations, integrations, resource, schemaVersion=None, branding=None, output=None):
    dataDict = {
        "name": name,
        "version": version,
        "minRequiredVersion": minRequiredVersion,
        "maxRequiredVersion": maxRequiredVersion,
        "translations": translations,
        "integrations": integrations,
        "resource": resource
    }
    if schemaVersion is not None:
        dataDict["schemaVersion"] = schemaVersion
    if branding:
        dataDict["branding"] = branding
    with open(output or name+'.json', 'w', encoding='utf-8') as file:
        json.dump(dataDict, file, indent=4, sort_keys=True)
        file.write('\n')

def strip_empty_sources(tsFiles):
    """
    Remove <message> entries with empty/whitespace <source> from .ts files.
    """
    for filename in tsFiles:
        try:
            tree = ET.parse(filename)
            root = tree.getroot()
            changed = False
            for context in list(root.findall('context')):
                for message in list(context.findall('message')):
                    source = message.find('source')
                    if source is None or (source.text is None) or (source.text.strip() == ''):
                        context.remove(message)
                        changed = True
                # remove empty contexts
                if len(context.findall('message')) == 0:
                    root.remove(context)
                    changed = True
            if changed:
                tree.write(filename, encoding='utf-8', xml_declaration=True)
                print("    stripped empty translations from", filename)
        except Exception as e:
            print("    failed to process", filename, e, file=sys.stderr)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='gui-v2-plugin-compiler',
        description='Compiles plugins for gui-v2 into json files')

    parser.add_argument('--rcc', nargs='?', default='') # debugging only...
    parser.add_argument('-n', '--name', default=os.path.basename(os.getcwd()), help='The name of your plugin')
    parser.add_argument('-v', '--version', default='1.0', help='The version of your plugin')
    parser.add_argument('-z', '--min-required-version', default='', help='The minimum gui-v2 version required for the plugin')
    parser.add_argument('-x', '--max-required-version', default='', help='The maximum gui-v2 version compatible with this plugin')
    parser.add_argument('-s', '--settings', default='', help='The main settings page .qml associated with your plugin')
    parser.add_argument('-d', '--devicelist', required=False, nargs='+', action='append', help='Triplet of product id, settings page .qml, and title text (or translation id)')
    parser.add_argument('-g', '--navigation', default='')
    parser.add_argument('-q', '--quickaccess', default='')
    parser.add_argument('-c', '--card', default='')
    parser.add_argument('-f', '--filter-empty-sources', action='store_true', help='Strip empty source entries from .ts files')
    parser.add_argument('-m', '--manifest', default='', help='Schema v2 partner-pack manifest')
    parser.add_argument('-o', '--output', default='', help='Compiled JSON output path')
    parser.add_argument('--wasm-bootstrap-dir', default='', help='Write a WASM branding descriptor and browser asset to this directory')
    parser.add_argument('--package-output', default='', help='Write a deterministic installable .vgp archive')

    args = parser.parse_args()

    manifest = None
    if args.manifest:
        manifest_path = os.path.abspath(args.manifest)
        os.chdir(os.path.dirname(manifest_path))
        try:
            manifest = load_manifest(os.path.basename(manifest_path))
        except (OSError, ValueError, json.JSONDecodeError) as error:
            print(f'\n\nERROR: Invalid partner-pack manifest: {error}', file=sys.stderr)
            sys.exit(1)
        args.name = manifest['name']
        args.version = manifest['version']
        args.min_required_version = manifest['minRequiredVersion']
        args.max_required_version = manifest['maxRequiredVersion']

    if not manifest and args.name != os.path.basename(os.getcwd()):
        print("\n\nERROR: plugin name does not match working directory name!")
        sys.exit(1)

    imageFiles = collect_filenames('.', '.svg')
    imageFiles += collect_filenames('.', '.png')
    qmlFiles = collect_filenames('.', '.qml')
    tsFiles = collect_filenames('.', '.ts')

    print("--- running lupdate")
    run_lupdate(qmlFiles, tsFiles, args.name)

    if args.filter_empty_sources and tsFiles:
        strip_empty_sources(tsFiles)

    print("--- running lrelease")
    run_lrelease(tsFiles, args.name)
    qmFiles = collect_filenames('.', '.qm')

    print("--- writing .qrc")
    write_qrc(qmlFiles, qmFiles, imageFiles, args.name)

    print("--- running rcc")
    try:
        rccFile = args.rcc if args.rcc else run_rcc(args.name)

        print("--- base64 encoding rcc data")
        resource = b64_encode_rcc(rccFile)
    except (RuntimeError, ValueError) as error:
        print(f'\n\nERROR: Unable to compile resources: {error}', file=sys.stderr)
        sys.exit(1)

    print("--- building translations array")
    translations = []
    for qmFile in qmFiles:
        translations.append("qrc:/" + args.name + "/" + qmFile)

    print("--- building integrations dictionary")
    integrations = []
    if len(args.settings) > 0:
        if not args.settings.endswith('.qml'):
            print("\n\nERROR: Invalid settings page specified, must be a .qml file")
            sys.exit(1)
        if not os.path.exists(args.settings):
            print(f"\n\nERROR: Settings page \"{args.settings}\" not found in current directory ({os.path.dirname(os.path.abspath(args.settings))})")
            sys.exit(1)
        settingsIntegration = {
            "type": 1,
            "url": "qrc:/" + args.name + "/" + args.settings
        }
        integrations.append(settingsIntegration)
    if args.devicelist:
        if len(args.devicelist) > 0:
            for integration in args.devicelist:
                if len(integration) != 3:
                    print("\n\nERROR: Invalid devicelist triplet!")
                    sys.exit(1)
                if not integration[0].startswith(('0x', '0X')):
                    print("\n\nERROR: Invalid product id specified in devicelist triplet, must be a hex string starting with 0x")
                    sys.exit(1)
                if not integration[1].endswith('.qml'):
                    print("\n\nERROR: Invalid settings page specified in devicelist triplet, must be a .qml file")
                    sys.exit(1)
                if not os.path.exists(integration[1]):
                    print(f"\n\nERROR: Settings page \"{integration[1]}\" not found in current directory ({os.path.dirname(os.path.abspath(integration[1]))})")
                    sys.exit(1)
                devicelistIntegration = {
                    "type": 2,
                    "productId": integration[0],
                    "url": "qrc:/" + args.name + "/" + integration[1],
                    "title": integration[2]
                }
                integrations.append(devicelistIntegration)
    if manifest:
        integrations = manifest['integrations']
    elif len(args.navigation) > 0:
        print("TODO: navigation...")
    if len(args.quickaccess) > 0:
        print("TODO: quick access...")
    if len(args.card) > 0:
        print("TODO: card...")

    print("--- writing compiled json")
    compiled_output = os.path.abspath(args.output or args.name+'.json')
    write_compiled_json(args.name, args.version, args.min_required_version, args.max_required_version,
        translations, integrations, resource,
        schemaVersion=manifest['schemaVersion'] if manifest else None,
        branding=manifest['branding'] if manifest else None,
        output=compiled_output)

    wasm_bootstrap_directory = ''
    if args.wasm_bootstrap_dir:
        if not manifest or not manifest['canonicalBranding']:
            print('\n\nERROR: --wasm-bootstrap-dir requires canonical partner.json branding', file=sys.stderr)
            sys.exit(1)
        try:
            wasm_bootstrap_directory = os.path.abspath(args.wasm_bootstrap_dir)
            write_wasm_bootstrap(wasm_bootstrap_directory, args.name,
                manifest['canonicalBranding'])
        except (OSError, ValueError) as error:
            print(f'\n\nERROR: Unable to write WASM bootstrap: {error}', file=sys.stderr)
            sys.exit(1)

    if args.package_output:
        print("--- writing partner package")
        try:
            write_partner_package(os.path.abspath(args.package_output), compiled_output,
                manifest, wasm_bootstrap_directory)
        except (OSError, ValueError) as error:
            print(f'\n\nERROR: Unable to write partner package: {error}', file=sys.stderr)
            sys.exit(1)

    print("--- done!")
    sys.exit(0)
