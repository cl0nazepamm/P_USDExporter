# Better USD exporter for 3dsMax (PowerUSD)

![PowerUSD Logo](icons/powerusd_logo.png)

USD export with auto stage assembly, variant sets, proxies and prim kind definitions.
## How does it work?

It exports everything to separate .USD file and assembles them. You can use auto-assembly or assembly tool. Please open the example scene to understand how script works better!

Dummy objects with USD properties modifier (can be found in Customize panel) can be used to define prim kinds and more. You can assign this modifier to objects in the scene aswell but there is not much point to it. Groups get converted to dummies due to how horrible 3dsmax group objects are. 

This script tries to be modular as possible! So you don't need to export the whole scene to update over and over again. It comes with single export that doesn't generate hirearchy json.


| Property | Values | Description |
|----------|--------|-------------|
| Geom Type | (auto), Xform, Scope | Prim container type |
| Kind | (none), assembly, group, component, subcomponent, model | USD Kind metadata |
| Purpose | default, render, proxy, guide | Rendering purpose |
| Instanceable | true/false | GPU instancing flag |
| Hidden | true/false | Start invisible |
| Active | true/false | Prim active state |
| Asset Version | string | Version tracking in assetInfo |
| Draw Mode | default, bounds, origin, cards | Viewport draw mode |
| Payload | true/false | Use payload instead of reference |


Filename suffixes are used for defining variants and proxies.

## Filename Suffixes

Object names control assembly behavior through suffixes:

| Suffix | Effect |
|--------|--------|
| `_VARIANT1`, `_VARIANT2`, ... | Assembled into a VariantSet on the parent prim |
| `_RENDER` | Sets `purpose = render` |
| `_PROXY` | Sets `purpose = proxy` |
| `_GUIDE` | Sets `purpose = guide` |
| `_PAYLOAD` | Referenced as payload instead of reference |

### Difference from standard USD export.

- Reads USD Properties from Max Attribute Holders and writes them to USD prims
- Strips the `/root` wrapper that MaxUSD adds (can be turned on again)
- Remaps material binding paths
- Handles variant set creation from `_VARIANT*` children
- Nests `/mtl` scope under the content prim for clean referencing

## Material Structure Cleanup

The Clean Material Structure fixes MaxUSD's default material export to produce cleaner USD Preview Surface shaders.

| Clean Off | Clean On |
|-----------|----------|
| ![off](images/clean_off.png) | ![on](images/clean_on.png) |
| ![off2](images/clean_off2.png) | ![on2](images/clean_on2.png) |

## Installation

Drag cloneTools folder to `AppData\Local\Autodesk\3dsMax\2026 - 64bit\ENU\scripts\`
then drag every `.ms` file to 3dsmax viewport to install.

## MAXUSD settings

![Correct_Settings](images/Correct_Settings.png)

Don't export whole scene with animation enabled. Use single export mode and send animated stuff. Use reassembler if needed.

## License

MIT


