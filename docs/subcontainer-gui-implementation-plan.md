# Sub-container GUI implementation plan

Companion to `venus-containers`' `docs/subcontainer-runtime-implementation-plan.md`,
which maps `VenusOS_Containers_Subcontainer_Runtime_Design_v1.docx` onto the
backend/D-Bus changes. This note maps the same design note's S6 ("GUIv2
interaction model", Figures 9-13) and S7 ("GUI rules") onto concrete
gui-v2 changes, using this repo's own conventions (`.github/architecture.md`,
`.github/device-settings.md`).

## 0. Starting point: there is no Containers GUI in this repo yet

Checked: no `*container*`-named file exists anywhere under `pages/`,
`components/`, `data/` or `src/` in this checkout, on either `main` or this
branch. `venus-containers`' own `dbus_service.py` has a forward-reference
comment to a `components/Containers.qml` that does not exist here. That
means the base Drop 3 container list/detail UI (plain start/stop/restart,
resources, D-Bus proxy status - everything *except* sub-containers) is a
prerequisite this plan assumes lands first or alongside it, not something
already in place to extend. Section 1 below is that minimum base scaffold;
Sections 2-5 are the sub-container-specific work the design note actually
asks for. If the base container GUI is being tracked as separate work,
Section 1 should be split out and only its interfaces (the data-layer
singleton, the per-container detail page, the D-Bus UID shape) need to be
agreed on now so Sections 2-5 have something concrete to attach to.

## 1. Base scaffold this depends on (prerequisite, not sub-container-specific)

Modeled on `data/Generators.qml` + `pages/settings/PageGensets.qml` +
`pages/settings/PageGenerator.qml` (list of instances -> detail page) and
`.github/device-settings.md`'s `ListSetting` hierarchy:

- `data/Containers.qml`: a `QtObject` singleton (`Component.onCompleted:
  Global.containers = root`, registered as `Containers {}` in
  `data/DataManager.qml`, and listed alongside `Global.generators` etc. in
  `Global.qml` per `.github/architecture.md`'s table) wrapping a model over
  `com.victronenergy.containers`'s published `/Containers/<dbus-safe-id>`
  children. `venus-containers/docs/dbus-api.md` gives the exact UID shape:
  `BackendConnection.uidPrefix() + "com.victronenergy.containers" +
  "/Containers/" + <id>`.
- Enumeration approach: unlike `Generators` (one `serviceType` across
  possibly many services, via `FilteredDeviceModel`), all containers live
  under **one** fixed service exposing many numbered children - structurally
  the same shape as `VeQItemChildModel { childId: "Link/ChargeCurrent",
  model: VeQItemFilteredServiceModel {...} }` used in
  `pages/settings/PageChargeCurrentLimits.qml`, or the `IOChannelGroupModel`
  C++ model (`src/iochannelgroupmodel.h`) if the plain-QML child model turns
  out not to give the sorting/filtering the container list needs (running
  count, name, state). Start with the QML-only approach (matches this
  repo's stated preference of C++ models only when a QML data wrapper isn't
  enough - contrast `data/Generators.qml`, all-QML, against
  `IOChannelGroupModel`, C++, which exists because plain-QML channel
  grouping wasn't sufficient); escalate to a C++ model only if it proves
  necessary.
- One top-level entry point: a `ListNavigation` row (new, e.g. in whatever
  settings page groups system-level services - candidate:
  `pages/settings/SettingsPage.qml` or a new `PageContainers.qml` reached
  the same way `PageSettingsBluetooth.qml` is) listing all registered
  containers, each a `ListNavigation` pushing
  `pages/settings/PageContainer.qml` for that UUID (mirrors the
  `PageDcGensets.qml` -> `Global.pageManager.pushPage("/pages/settings/
  PageGensets.qml", ...)` pattern). Containers are not "devices" in the
  electrical-quantity sense `AllDevicesModel`/`DeviceListPage.qml` are built
  around, so plugging into that generic device list is probably wrong
  fit - treat this as its own settings-style page, not a
  `DeviceListDelegate_<serviceType>.qml` entry.
- `PageContainer.qml`: per-container detail (Figure 9's "normal" state) -
  name, image, state, start/stop, resources - the existing
  `ListSpinBox`/`ListSwitch`/`ListText` vocabulary from
  `.github/device-settings.md`, nothing new needed structurally.
- `data/mock/ContainersImpl.qml`: mock backend so desktop/WASM dev builds
  work without a live `dbus-containers`, following `GeneratorsImpl.qml`'s
  `Instantiator` + fake service UID pattern.

## 2. Sub-container data layer additions

Once Section 1's per-container model exists, extend it with the
`ContainerRuntime` subtree from the backend plan's D-Bus table:

```text
/Containers/<ID>/ContainerRuntime/Enabled
/Containers/<ID>/ContainerRuntime/State
/Containers/<ID>/ContainerRuntime/Children/Count
/Containers/<ID>/ContainerRuntime/Children/Running
/Containers/<ID>/ContainerRuntime/Resources/MemoryLimitBytes   (R/W)
/Containers/<ID>/ContainerRuntime/Resources/CpuLimit           (R/W)
/Containers/<ID>/ContainerRuntime/Resources/PidsLimit          (R/W)
/Containers/<ID>/ContainerRuntime/Resources/MemoryUsedBytes
/Containers/<ID>/ContainerRuntime/Resources/CpuUsage
/Containers/<ID>/ContainerRuntime/Resources/PidsUsed
```

- Each is a plain `VeQuickItem { uid: containerUid + "/ContainerRuntime/..." }`
  binding, same as every other data leaf in this codebase - no new backend
  abstraction needed on the GUI side, per `.github/device-settings.md`'s
  "avoid manual value management, bind `dataItem.uid` directly."
- Optional per-child observation objects (backend plan S6, "may publish
  read-only child objects") enumerate under
  `/Containers/<ID>/ContainerRuntime/Children/<n>/{RuntimeId,Name,Image,
  State,...}` - a second `VeQItemChildModel` scoped under the parent
  container's own path, same technique as the top-level container
  enumeration in Section 1, just nested one level deeper.
- `data/mock/ContainersImpl.qml` (or a new sibling
  `ContainerRuntimeImpl.qml`) gets mock values for all of the above plus a
  few synthetic children, so Sections 3-4's pages are buildable and
  visually testable before real backend support exists - same role
  `GeneratorsImpl.qml` plays for `PageGenerator.qml`.

## 3. Parent container detail page changes (Figure 9)

In `PageContainer.qml` (Section 1): add one `ListNavigation` row, visible
only when `containerRuntime.enabled` -

```qml
ListNavigation {
    text: qsTrId("page_container_sub_containers")   // "Sub-containers"
    secondaryText: qsTrId("page_container_sub_containers_count")
        .arg(runtimeChildrenRunning.value).arg(runtimeChildrenCount.value)
        // "%1 of %2 running"
    visible: runtimeEnabled.value === true
    onClicked: Global.pageManager.pushPage("/pages/settings/PageContainerRuntime.qml",
        { containerUid: root.containerUid })
}
```

This is the exact shape `ListNavigation`'s own `secondaryText` property was
built for (see `components/listitems/core/ListNavigation.qml`) - no new
list-item component needed here.

Degraded-state handling (S7: "If the runtime API is degraded, the parent
may remain Running, but the Sub-containers row must show an explicit
warning/degraded state") needs a visible indicator when
`ContainerRuntime/State` is `DEGRADED` - reuse whatever color/icon token
this codebase's existing alarm/warning list rows already use (check
`components/listitems/ListAlarmState.qml` and its background indicator
color for the established convention) rather than inventing a new one;
likely `ListSetting`'s `indicatorColor`/`backgroundIndicatorColor` on this
`ListNavigation` row, or an inline warning icon next to `secondaryText`.

Everything else on this page (name, image, lifecycle, parent's own
resources) is explicitly **unchanged** per S6/S7 - no other edits to this
page.

## 4. Sub-containers page (Figures 10, 12, 13)

New `pages/settings/PageContainerRuntime.qml`:

```qml
Page {
    id: root
    required property string containerUid
    title: qsTrId("page_container_runtime_title")   // "Sub-containers"

    GradientListView {
        model: VisibleItemModel {
            ListQuantity {
                text: qsTrId("page_container_runtime_memory_used")
                dataItem.uid: root.containerUid + "/ContainerRuntime/Resources/MemoryUsedBytes"
                unit: VenusOS.Units_Byte  // confirm exact unit enum
            }
            // same read-only pattern for CpuUsage, PidsUsed

            ListSpinBox {
                text: qsTrId("page_container_runtime_memory_limit")
                dataItem.uid: root.containerUid + "/ContainerRuntime/Resources/MemoryLimitBytes"
                writeAccessLevel: VenusOS.User_AccessType_Installer   // confirm level
            }
            // same ListSpinBox pattern for CpuLimit, PidsLimit - this is
            // Figure 13's "Focused editor follows the existing GUIv2
            // resource-value pattern": ListSpinBox already opens a
            // NumberSelectorDialog on click (see
            // components/listitems/ListEvcsSetCurrentSpinBox.qml for the
            // single-value precedent, or ListSpinBoxRange.qml if the
            // design note actually wants a from/to range rather than a
            // single ceiling - S2's schema only has one value per field,
            // so plain ListSpinBox is the right fit, not the Range variant)

            ListNavigation {
                text: qsTrId("page_container_runtime_children")
                secondaryText: "%1".arg(childrenCountItem.value)
                onClicked: Global.pageManager.pushPage(
                    "/pages/settings/PageContainerRuntimeChildren.qml",
                    { containerUid: root.containerUid })
            }
        }
    }
}
```

S7's ordering rule ("aggregate child usage and aggregate limits before the
individual child list") is satisfied by listing the `ListQuantity`/
`ListSpinBox` rows before the `ListNavigation` to the child list, as above.

Live-edit requirement (S4.1, "writable at runtime... does not recreate the
parent"): no GUI-side work needed beyond the plain `ListSpinBox` ->
`dataItem.setValue()` call - that's already how every other live-writable
D-Bus value in this codebase behaves; the "don't recreate" guarantee is
entirely a backend-side property (`venus-containers`' `update_runtime_
resources`, not this repo's concern).

## 5. Sub-container list page (Figure 11)

New `pages/settings/PageContainerRuntimeChildren.qml`: a `GradientListView`
over the per-child `VeQItemChildModel` from Section 2, delegate built from
**read-only** core list items only -

```qml
delegate: ListText {
    text: model.name        // or ListQuantityGroup for state + image + usage
    caption: model.image
}
```

Hard rule carried over from the design note and worth stating explicitly
here since it's easy to violate by habit: **no `ListButton`, `ListSwitch`,
or any `ListSetting` subtype that calls `dataItem.setValue()` against a
child's own path anywhere on this page.** S5/S7 are explicit that Venus
"does not start, stop, delete or recreate" children and must not expose
`DesiredState` or other lifecycle writes for them even by omission - a
generic reusable delegate that happens to include a start/stop button
(easy to reach for, since that's what the parent's own detail page has)
would violate this. Every row here is `ListText`/`ListQuantity`-family
only.

## 6. GUI rules (S7) as concrete bindings, not just prose

| Rule | Enforcement |
|---|---|
| Normal containers show no Sub-containers row or child-runtime controls | `visible: runtimeEnabled.value === true` on the Section 3 row (not just `enabled: false` - per `.github/device-settings.md`'s interaction rules, but this is a structural visibility gate, not an access-level one, so `visible` is correct here, unlike the "never set enabled=false" rule which is about access-level-gated *interactive* items) |
| "N of M running" only when capability enabled | Same `visible` binding; `secondaryText` binding only evaluates once visible |
| Aggregate summary before child list | Row ordering in `PageContainerRuntime.qml`, Section 4 |
| Aggregate limits writable while running | No extra binding - `ListSpinBox` is inherently live; just don't add an `enabled: state === Running` guard that isn't asked for |
| Individual child rows read-only | No writable list items on `PageContainerRuntimeChildren.qml` at all, Section 5 |
| Degraded runtime shows explicit warning | Indicator binding in Section 3 |
| No live "shared -> dedicated" conversion UI | Simply never build one - `PageContainer.qml`'s `hostIdentity`/`containerRuntime` fields, if shown at all, are `ListText` display only, never `ListSwitch`/`ListRadioButtonGroup` |

## 7. Tests

Per `.github/unit-tests.md`/`.github/visual-regression-tests.md`
conventions (file names inferred from `tests/` top-level, which mirrors
`src/` one-to-one for C++ model tests):

- If Section 1/2 end up needing a C++ model (the `IOChannelGroupModel`
  fallback), it gets a `tests/<modelname>/` directory matching the existing
  per-model test layout (e.g. `tests/iochannelgroupmodel/`).
- Visual regression snapshots for the three new pages
  (`PageContainer.qml` with the Sub-containers row visible/hidden,
  `PageContainerRuntime.qml`, `PageContainerRuntimeChildren.qml`) plus the
  degraded-state indicator variant, using `tests/ui/RecursivePageCapture.qml`
  the way existing pages are captured (confirm exact mechanism in
  `.github/visual-regression-tests.md` before writing these - not read in
  detail for this plan).
- Mock-data-driven smoke coverage (`tests/ui/smoke/`) exercising: open
  parent detail -> see Sub-containers row -> open it -> edit an aggregate
  limit -> open children list -> confirm no writable controls are
  reachable there (a negative test, guarding rule 5/6 above).

## 8. Sequencing relative to the backend plan

GUIv2 work here can only be exercised end-to-end once `venus-containers`
publishes the `/ContainerRuntime/*` tree (its plan's step 5), but Sections
2-5 above can be built and visually verified against
`data/mock/ContainersImpl.qml` mock data well before that - same
decoupling this codebase already relies on for every other page (`Mock`
producer backend, `MockManager` singleton). Recommended order: Section 1
(base scaffold, needed regardless) -> Section 2 mock data -> Sections 3-5
against mocks -> swap to live data once the backend's D-Bus tree lands,
same integration step as any other feature here.
