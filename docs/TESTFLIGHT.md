# Getting Baliztic Zero onto TestFlight

What has to happen before the app can be installed from TestFlight on your own iPhone, with no cable and no Developer Mode. Internal testing only, meaning you and anyone on your App Store Connect team. Outside testers come later (see the end).

**Identifiers**

| | |
| --- | --- |
| Bundle ID | `com.balizticzero.app` |
| Team | `TRSF93SDY9` (individual, paid) |
| Version / build | `1.0` / `1` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`) |

## 1. In the code (done in PR #8)

- [x] Signed with the team, automatic signing (`DEVELOPMENT_TEAM` in `project.yml`).
- [x] WeatherKit entitlement (`BalizticZero/BalizticZero.entitlements`).
- [x] App icon: `Assets.xcassets/AppIcon`, 1024×1024, opaque. Regenerate it with `tools/render-app-icon.swift`.
- [x] `ITSAppUsesNonExemptEncryption = NO` in `Info.plist`. The app only uses Apple's built-in HTTPS, which is exempt. Without this key every build waits in TestFlight until you answer the encryption question.
- [x] Permission text for location and motion (`NSLocationWhenInUseUsageDescription`, `NSMotionUsageDescription`).
- [x] Launch screen, portrait only, iPhone only.
- [ ] **Merge PR #8** once the Unit tests check passes and you approve it. Archive from `main` after that.

## 2. Apple Developer portal (once)

developer.apple.com/account → **Certificates, IDs & Profiles** → **Identifiers**

- [ ] `com.balizticzero.app` is listed. If not, click **+** → **App IDs** → **App** → Explicit bundle ID `com.balizticzero.app`. Running the app once from Xcode with signing on also registers it.
- [ ] Open it. On the **Capabilities** tab, tick **WeatherKit**.
- [ ] On the **App Services** tab, tick **WeatherKit** too. Both are needed.
- [ ] **Save**, then **Confirm**. WeatherKit can take about 30 minutes to start answering. Until then the app says "Apple Weather refused the request", and everything else works.

## 3. App Store Connect (once)

appstoreconnect.apple.com → **Apps** → **+** → **New App**

- [ ] Platform **iOS**. Bundle ID `com.balizticzero.app`, which shows in the list once step 2 is done. SKU: anything, such as `balizticzero`. User access: **Full Access**.
- [ ] Name: it must be unique across the App Store. If "Baliztic Zero" is taken, try a variant. This is only the store listing; the name on your home screen comes from `CFBundleDisplayName`.
- [ ] Primary language and category (Utilities or Sports). Nothing else on the app page is needed for internal TestFlight.

## 4. Archive and upload (every build)

In Xcode, on `main` with a clean tree:

- [ ] Run destination: **Any iOS Device (arm64)**. Archive is greyed out for a Simulator.
- [ ] **Product → Archive.**
- [ ] In the Organizer, choose **Distribute App** → **TestFlight & App Store**. Xcode creates the distribution certificate and profile the first time.
- [ ] Leave **Manage Version and Build Number** ticked, so each upload gets a new build number. App Store Connect rejects a build number it has already seen.
- [ ] Wait for the "processing complete" email, usually 5 to 30 minutes.

## 5. TestFlight (once, then automatic)

- [ ] App Store Connect → your app → **TestFlight** → **Internal Testing** → **+**. Create a group and add yourself. Internal builds skip Beta App Review.
- [ ] Add the processed build to the group.
- [ ] On the iPhone, install **TestFlight** from the App Store, sign in with the same Apple ID, accept the invite, and install.

After this, every new archive you upload shows up in TestFlight on its own.

## 6. First run on the phone: what to check

The Simulator could not exercise these:

- [ ] Location prompt on the Conditions tab. Latitude, longitude and altitude fill from GPS.
- [ ] Barometer fills station pressure, after the motion permission prompt.
- [ ] Compass heading fills azimuth. This code has never run, because the Simulator has no compass.
- [ ] **Measure incline** with the phone along the barrel.
- [ ] **Update weather** fills temperature, pressure, humidity and wind, and the Apple Weather mark and link appear. Set the altitude first, because station pressure depends on it.
- [ ] Scrolling on every tab. If it works with your finger, the earlier mouse-wheel problem was the Simulator's.
- [ ] Dialing in MRAD and MOA on a real load, against your scope's turret.

## Known gaps (fine for testing, worth knowing)

- **Azimuth is magnetic** while Coriolis and Apple Weather's wind use true north. The wind angle is off by your local declination, which can be 10° or more ([#1](https://github.com/jdothoffman/BalizticZero/issues/1)).
- **Elevation lookup** is not connected. Altitude comes from GPS or is typed in ([#3](https://github.com/jdothoffman/BalizticZero/issues/3)).
- **The AI advisor** is a placeholder and hidden ([#4](https://github.com/jdothoffman/BalizticZero/issues/4)).

## Later: outside testers

External testers, by email or public link, need more first:
- A **Beta App Review** of the first build.
- **Test Information** in TestFlight: a beta description, a feedback email, and contact details.
- Very likely a **privacy policy URL**, because the app uses location.

A public App Store release additionally needs screenshots, the App Privacy questionnaire, and full App Review.
