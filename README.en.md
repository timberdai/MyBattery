# MyBattery

**A small macOS menu bar app for battery status, charging power and everyday battery information.**

[Download](https://github.com/timberdai/MyBattery/releases/latest) · [简体中文](README.md) · [Report an issue](https://github.com/timberdai/MyBattery/issues)

See charge percentage and whether your Mac is plugged in or charging at a glance. Open the compact native menu for live power, adapter information, battery temperature, health, cycles, capacities, fan speed and power-source time over the last 24 hours. Optional green edge glow marks a power connection; toggle it with a checkmark in the menu.

MyBattery reads information only. Apple’s Optimized Battery Charging and charge limits remain managed in System Settings. Battery health describes current capacity, not a prediction of remaining years.

## Install

Requires **macOS 13 or later**. The downloadable app is built for **Apple Silicon**.

1. Download `MyBattery-0.1.0-arm64.dmg` from [Releases](https://github.com/timberdai/MyBattery/releases/latest).
2. Open it and drag `MyBattery.app` onto `Applications`.
3. Launch it from Applications. It lives in the menu bar, with no Dock icon.
4. Enable **Launch at Login** if desired.

The app is not notarized by Apple. If macOS blocks the first launch, follow the **Open Anyway** prompt in **System Settings → Privacy & Security**. Battery and fan reads do not require administrator privileges. Building locally is also supported.

**Source code (zip)** and **Source code (tar.gz)** contain source for developers; download the DMG to use the app. Release notes include the DMG SHA256 checksum.

## Understand the watts

| Display | Meaning |
| --- | --- |
| Charging | Power entering the battery now. |
| Discharge | Power supplied by the battery now. |
| Input | External power entering the Mac, including system use and possible charging. |
| Load | System-reported load, not battery charging power. |
| Adapter | System-reported adapter wattage and PD / USB / MagSafe type. |
| PD profile | Wattage calculated from the reported power parameters, not a capture of USB PD negotiation packets. |

An adapter and profile may both show 100 W while actual input is much lower and the battery is not charging at its 80% limit. **Input** and **Charging** are the readings to watch for current consumption and battery charging.

Sensor availability varies across Macs. Missing sensors are hidden, unknown values are not invented, and an unknown PD revision is not guessed. The last-24-hour summary measures power-source time from macOS logs, including corresponding sleep intervals.

## Automatic language

A Chinese first system language uses Simplified Chinese. English and all other first languages use English. There is no manual language selector; relaunch after changing the system language.

## Build from source

Requires Swift 5.9 or newer and macOS development tools. StatusItemKit source is included in the repository.

```bash
git clone https://github.com/timberdai/MyBattery.git
cd MyBattery
./scripts/install.sh
```

The script builds, signs locally, installs into `~/Applications/MyBattery.app` and launches the app. Use `./scripts/dev-reload.sh` after editing.

## Development

```bash
swift build -c release
swift test
./scripts/run-round2-tests.sh
```

Full XCTest requires Xcode with the test framework. The last command directly tests production parsing, power formatting, boundaries, read-only SMC and bilingual row widths; it does not replace the full XCTest suite. On a desktop, `./scripts/run-round2-tests.sh --glow` checks window lifecycles.

Issues and pull requests are welcome. Include your macOS version, Mac model, app version and steps to reproduce. Remove device serial numbers from reports.

`VERSION` defines the version, currently **0.1.0**. `./scripts/package-release.sh` creates a DMG and checksum under `build/`. Main/PR builds run checks; matching `mybattery-vX.Y.Z` tags publish releases. The first public release is titled `v0.1.0`, using `mybattery-v0.1.0` to preserve existing historical tags.

## Inspiration and credits

- [BetterBattery](https://github.com/michaelmax98/BetterBattery), for the small menu bar tool and live charging-power idea.
- [battery-time-menubar](https://github.com/nicholaspsmith/battery-time-menubar), the code foundation of MyBattery. Original copyrights and history are retained.
- [StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit), for menu bar, version and login support. See [vendored source provenance](Vendor/StatusItemKit/README.md).

By [timberdai](https://github.com/timberdai). Licensed under [MPL-2.0](LICENSE).
