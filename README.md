# Baliztic Zero

An iPhone long-range ballistic calculator that runs entirely on the device. Enter the shot, the air, and the load, and it returns the elevation and windage to dial, how to hold on the reticle, and a range table.

> Every solution is an estimate. Confirm it with live fire on a known range before relying on it.

## What it does

The app has five tabs:

| Tab | Purpose |
| --- | --- |
| **Shot** | Range, zero, incline (can be measured with the phone), wind speed and direction, shot azimuth. |
| **Conditions** | Temperature, station pressure, humidity, altitude, latitude/longitude. Imperial or metric. Can fill location, altitude, and pressure from the phone's GPS and barometer. |
| **Load** | Saved load profiles: bullet (velocity, weight, diameter, length, BC, G1/G7), rifle (sight height, zero, twist), and scope (click value, turret travel, rail cant, reticle unit, focal plane, hash spacing). |
| **Solution** | Correction at the target in the scope's unit, with clicks and turret turns. Reticle hold (including second-focal-plane scaling), travel-limit warnings, flight data, and a breakdown of wind drift, spin drift, and Coriolis. |
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
  Services/       Weather and elevation provider protocols (not yet connected)
  AI/             Advisor protocol placeholder (not yet connected)
BalizticZeroTests/  Solver and scope-dial unit tests
project.yml         XcodeGen spec; the .xcodeproj is generated from it
```

## Building

Requirements: Xcode 26 and an iOS 18+ simulator or device. Code signing is turned off in the project, so set your own team to run on a phone.

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding or removing source files, regenerate it:

```sh
brew install xcodegen   # once
xcodegen generate
```

Build and test from the command line:

```sh
xcodebuild -project BalizticZero.xcodeproj -scheme BalizticZero \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -derivedDataPath build build

xcodebuild -project BalizticZero.xcodeproj -scheme BalizticZero \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -derivedDataPath build test
```

The tests check the solver against a vacuum analytic drop, published G1/G7 checkpoints, and a reference zero angle. They also check that the wind, incline, temperature, spin-drift, and Coriolis effects push in the right direction, and check the scope dial and reticle-hold math.

## Design

The UI is black with a single rose gold accent, tabular numbers, and no decoration. Colors and shared components (`SectionLabel`, `Panel`, `DataPanel`) live in `Features/Theme.swift`. Screens use those rather than defining their own styling.

## Not done yet

- **Azimuth is magnetic.** Coriolis uses it as if it were true north until a declination model is added. ([#1](https://github.com/jdothoffman/BalizticZero/issues/1))
- **Weather and elevation lookups are stubbed.** `WeatherProviding` and `ElevationProviding` have notes on free sources (Open-Meteo, NOAA), but nothing is connected. GPS and the barometer are the live sources. ([#2](https://github.com/jdothoffman/BalizticZero/issues/2), [#3](https://github.com/jdothoffman/BalizticZero/issues/3))
- **The phone has no thermometer or humidity sensor**, so those are entered by hand until weather lookup lands. ([#2](https://github.com/jdothoffman/BalizticZero/issues/2))
- **The AI advisor is a placeholder.** `BallisticAdvising` exists, but the solver never calls it and the button is hidden. ([#4](https://github.com/jdothoffman/BalizticZero/issues/4))
