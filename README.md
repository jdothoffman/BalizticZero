# Baliztic Zero

An iPhone long-range ballistic calculator that runs entirely on the device. Enter the shot, the air, and the load, and it returns the elevation and windage to dial, how to hold on the reticle, and a range table.

> Every solution is an estimate. Confirm it with live fire on a known range before relying on it.

## What it does

The app has five tabs:

| Tab | Purpose |
| --- | --- |
| **Shot** | Range, zero, incline (can be measured with the phone), wind speed and direction, shot azimuth. |
| **Conditions** | Temperature, station pressure, humidity, altitude, latitude/longitude. Imperial or metric. Can fill location, altitude, and pressure from the phone's GPS and barometer, and temperature, pressure, humidity, and wind from Apple Weather. |
| **Load** | Saved load profiles: bullet (velocity, weight, diameter, length, BC, G1/G7), rifle (sight height, zero, twist), and scope (click value, turret travel, rail cant, reticle unit, focal plane, hash spacing). |
| **Solution** | Correction at the target in the scope's unit (MOA or MRAD), with turret turns, the turret reading to dial, and clicks. Reticle hold (including second-focal-plane scaling), travel-limit warnings, flight data, and a breakdown of wind drift, spin drift, and Coriolis. |
| **Table** | Elevation, windage, velocity, time of flight, and energy every 100 yards. |

The solution recomputes whenever any input changes.

## How the solver works

`TrajectorySolver` is a point-mass solver. It integrates the bullet's flight with fourth-order Runge–Kutta in a horizontal shot frame (x downrange, y up, z to the shooter's right).

- **Drag:** standard G1 and G7 reference curves (`DragTable`), scaled by the ballistic coefficient and the local air density.
- **Air:** density from the CIPM-2007 moist-air equation (temperature, station pressure, humidity), with a standard lapse rate applied over the flight (`AtmosphereModel`).
- **Zero:** the bore angle is solved for a flat, no-wind zero in the current air, then reused for the actual shot.
- **Incline:** the line of sight is tilted by the incline, and corrections are measured perpendicular to it.
- **Wind:** a full 3D wind vector from speed, direction, and shot azimuth (`Wind`).
- **Spin drift:** Miller stability factor plus the Litz time-of-flight approximation (`SpinDrift`).
- **Coriolis:** from latitude and azimuth, both horizontal and vertical (`Coriolis`).
- **Scope:** `ScopeDial` converts the correction into clicks and turns, checks turret travel (including a canted rail), and works out reticle holds for first- and second-focal-plane scopes.

## Project layout

```
BalizticZero/
  App/            CalculatorStore: app state, inputs, recompute, sensor plumbing
  Engine/         Solver, drag tables, atmosphere, wind/spin/Coriolis, scope dial math
  Models/         Load profiles (SwiftData), atmosphere, wind, shot context, solution types
  Features/       SwiftUI screens, shared theme, display formatting
  Sensors/        CoreLocation and CoreMotion: GPS, barometer, heading, incline
  Services/       Weather (Apple WeatherKit) and elevation (not yet connected) providers
  AI/             Advisor protocol placeholder (not yet connected)
BalizticZeroTests/  Solver, scope-dial, and weather unit tests
project.yml         XcodeGen spec; the .xcodeproj is generated from it
api/                Go advisor API: takes a solved shot, asks Claude to explain it
deploy/             Deploy script, systemd unit, and Caddy config for the API's Azure VM
```

## Building

Requirements: Xcode 26 and an iOS 18+ simulator or device.

The app is signed with the owner's team (`DEVELOPMENT_TEAM` in `project.yml`) because WeatherKit only answers signed builds that carry the WeatherKit entitlement, with WeatherKit enabled for the app ID `com.balizticzero.app` in the developer portal. To build under another team, change `DEVELOPMENT_TEAM` and enable WeatherKit for your own app ID. Everything except weather works unsigned.

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding or removing source files, regenerate it:

```sh
brew install xcodegen   # once
xcodegen generate
```

Build and test from the command line. Signing needs Xcode's accounts, so either add `-allowProvisioningUpdates` or build unsigned with `CODE_SIGNING_ALLOWED=NO` (weather lookups then fail, everything else works):

```sh
xcodebuild -project BalizticZero.xcodeproj -scheme BalizticZero \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -derivedDataPath build build

xcodebuild -project BalizticZero.xcodeproj -scheme BalizticZero \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -derivedDataPath build test
```

Every pull request to `main` runs these tests on a GitHub macOS runner (`.github/workflows/tests.yml`), and the "Unit tests" check must pass before it can merge.

The tests check the solver against a vacuum analytic drop, published G1/G7 checkpoints, and a reference zero angle. They also check that the wind, incline, temperature, spin-drift, and Coriolis effects push in the right direction, and check the scope dial and reticle-hold math.

## Advisor API

`api/` is a small Go service the app will call to have Claude explain a solved shot in plain language. The phone sends the numbers it already solved; the server builds the prompt and holds the Anthropic API key, so the key never ships in the app. It uses the official Anthropic Go SDK.

```sh
cd api && go test ./...
```

The "API tests" check runs gofmt, vet, the tests, and a Linux build on every pull request (`.github/workflows/api.yml`).

It runs on an Azure VM behind Caddy, which provides HTTPS. Only port 443 is open. `deploy/deploy.sh` does everything from this Mac with the Azure CLI and SSH:

```sh
deploy/deploy.sh check     # read-only: Azure, SSH, Go, what is set up
deploy/deploy.sh set-key   # prompt for the Anthropic API key and store it on the VM (root-only)
deploy/deploy.sh setup     # once: DNS name, port 443, Caddy, service user
deploy/deploy.sh deploy    # test, build, upload, restart; rolls back if the health check fails
deploy/deploy.sh status    # service state and https://<host>/healthz
```

Secrets live only in `/etc/baliztic-api/env` on the VM. Never put the API key in the repo.

## Design

The UI is black with a single rose gold accent, tabular numbers, and no decoration. Colors and shared components (`SectionLabel`, `Panel`, `DataPanel`) live in `Features/Theme.swift`. Screens use those rather than defining their own styling.

## Not done yet

- **Azimuth is magnetic.** Coriolis uses it as if it were true north until a declination model is added. ([#1](https://github.com/jdothoffman/BalizticZero/issues/1))
- **Elevation lookup is stubbed.** `ElevationProviding` exists but nothing is connected, so altitude comes from GPS or is typed in. ([#3](https://github.com/jdothoffman/BalizticZero/issues/3))
- **Weather wind is for the area, against a magnetic azimuth.** Apple Weather's wind direction is relative to true north while the shot azimuth is magnetic, so the wind angle is off by the local declination until [#1](https://github.com/jdothoffman/BalizticZero/issues/1) lands. Area wind is also not the wind on your line; treat it as a starting point.
- **The app does not call the advisor yet.** The API in `api/` is built, but `BallisticAdvising` in the app is still a placeholder and the button is hidden. ([#4](https://github.com/jdothoffman/BalizticZero/issues/4))
