# Wallpaper Swap

Paired friends send each other photos. The photo you send is what shows up on their phone, cropped to a screen.

iOS does not let an app change the wallpaper on its own. Wallpaper Swap does the closest things that are actually allowed:

- It puts the photo in a full-bleed Home Screen widget (small, medium, and large) and in Lock Screen widgets (circular, rectangular, and inline). "Full-bleed" means the photo goes to the edge of the widget, with the system padding turned off. Lock Screen widgets are still small; iOS does not offer a third-party widget that covers the whole Lock Screen.
- It publishes a Shortcuts action, **Get Latest Wallpaper**, that returns the newest photo. A Shortcut can pass that photo to the system **Set Wallpaper** action. The Guide tab in the app has the steps.

You can try the whole flow on one iPhone, or pair with a friend.

## What you can do

- Pair with one friend using a 6-character invite code.
- Pick a photo or take one, then pinch and drag to frame it to this phone's screen. The picture that gets sent is rendered at the phone's pixel size.
- Keep a history of what you sent and what you received. Any of those can be put back on your screen, saved to Photos, or deleted.
- Try a sample photo before anyone has sent you one, so the Shortcut has something to return.

## How photos move

There are three modes. The default needs no account and no API keys.

| Mode | What it does | What you need |
| --- | --- | --- |
| This iPhone | Pairs with a name you type. Nothing leaves the phone. Turn on "Also show photos I send" to see your own crop as the wallpaper. | Nothing |
| Nearby | Two iPhones find each other on the local network with the invite code. | A free Apple ID. Both apps open, same Wi-Fi. |
| iCloud | The same invite-code room, stored in CloudKit, so you don't have to be together. | A paid Apple Developer Program membership, the iCloud entitlement, and one CloudKit index. See below. |

Nearby is not push. If the other phone doesn't have the app open, the photo waits until it does. iCloud is the mode that works when you're apart, and it is off until you turn the entitlement on.

iCloud rooms live in the public CloudKit database. Anyone who has the code can read the photos in that room, so treat the code like a password. Don't post it.

## Requirements

- A Mac with Xcode 16 or later. Xcode 26 is fine.
- An iPhone running iOS 17 or later. The Simulator works for the interface and for "This iPhone" mode. The camera and Nearby need a real phone.
- A free Apple ID (a Personal Team in Xcode) is enough to install the app, pair nearby, and use the Shortcut.
- A paid Apple Developer Program membership ($99/year) is only needed for the two optional capabilities below. Leave them off and the project still signs.

## Open the project

The Xcode project is already generated. Open `WallpaperSwap.xcodeproj`. You do not need XcodeGen, CocoaPods, or a secrets file.

`project.yml` describes the same two targets if you later want to regenerate with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen generate` from the repo root). The checked-in project is the one to open. Regenerating will rewrite it, so only do that if you mean to.

Bundle ids and the optional iCloud container live in one file: `Config/Identifiers.xcconfig`.

```
APP_BUNDLE_IDENTIFIER = app.wallpaperswap.ios
WIDGET_BUNDLE_IDENTIFIER = $(APP_BUNDLE_IDENTIFIER).widget
APP_GROUP_ID = group.app.wallpaperswap.shared
CLOUDKIT_CONTAINER_ID = iCloud.app.wallpaperswap.ios
```

Which entitlements get signed is selected in `Config/App.xcconfig` and `Config/Widget.xcconfig`. The free files are selected. Those files are empty on purpose.

## Install it on your iPhone with a free Apple ID

1. Install Xcode from the Mac App Store and open it once so it can finish installing components.
2. In Xcode, choose Settings → Accounts, and sign in with your Apple ID. The team should say **Personal Team**. You do not need to join the paid program.
3. Open `WallpaperSwap.xcodeproj`.
4. Connect the iPhone, unlock it, and tap Trust if the phone asks. If the phone doesn't appear, check Finder is allowed to see it and that Developer Mode is on (Settings → Privacy & Security → Developer Mode) on iOS versions that require it.
5. In the Xcode toolbar, set the scheme to **WallpaperSwap** and the destination to your iPhone, not a simulator.
6. Select the **WallpaperSwap** target, open Signing & Capabilities, check **Automatically manage signing**, and set Team to your Personal Team.
7. Select the **WallpaperSwapWidget** target and set the same Team. Both targets have to be signed by the same person or the embed step fails.
8. Press Run.

The first install usually fails until the phone trusts you. On the iPhone open Settings → General → VPN & Device Management, tap your Apple ID under Developer App, and tap Trust. Then press Run again.

A free provisioning profile lasts **7 days**. When the app stops opening, plug the phone back in and press Run. Apple also caps a free account at a handful of App IDs and installed apps (recently: 10 App IDs, 3 apps on the device, 3 devices). Those limits change. Deleting an old personally signed app frees a slot. This project registers two App IDs, one for the app and one for the widget.

If Xcode says the bundle id can't be registered, change `APP_BUNDLE_IDENTIFIER` in `Config/Identifiers.xcconfig` to something unique to you, such as `app.yourname.wallpaperswap`. The widget id is `$(APP_BUNDLE_IDENTIFIER).widget`, so it follows. Don't also set the bundle id in the target's Build Settings. A value typed there overrides the xcconfig.

### Try it before you have a second phone

1. Enter your name.
2. Tap Pair with a friend, leave the mode on **This iPhone**, type a friend's name, and leave "Also show photos I send" on.
3. Send a photo and frame it, or tap **Try a sample photo**.
4. Open the Guide tab and build the Shortcut. The sample (or the photo you just framed) is what Get Latest Wallpaper returns.

To pair for real, both phones install the app, both choose **Nearby**, one person creates a code, the other types it. Leave both apps in the foreground.

## The widgets, and the paid switch

The widget extension is part of the app and installs with a free Apple ID. It cannot see the photo until both targets are signed with an **App Group**. A Personal Team cannot sign that capability. With the free entitlements, the widget installs and shows its empty state. The Shortcut still works, because that action runs in the app and reads the app's own files.

When you have a paid membership and you want the widgets to update:

1. In `Config/App.xcconfig`, comment the Free line and uncomment `WallpaperSwap-Paid.entitlements`.
2. In `Config/Widget.xcconfig`, comment the Free line and uncomment `WallpaperSwapWidget-Paid.entitlements`.
3. If `group.app.wallpaperswap.shared` is already taken on your team, change `APP_GROUP_ID` in `Config/Identifiers.xcconfig`. That value is written into both Info.plists and substituted into the Paid entitlement files when Xcode signs.
4. Set the paid team on both targets and press Run.

The app copies any photos it saved before the group existed into the shared container on the next launch. Settings shows whether widget sharing is actually available.

If you see **"Personal development teams, including …, do not support the App Groups capability"**, you are still on a free team. Switch both xcconfig files back to the Free entitlements.

## iCloud sync

Skip this unless you want pairing to work when the two phones aren't on the same network. Nearby already works without it.

1. Do the App Group switch above. The widget still uses the Paid file, not the iCloud one.
2. In `Config/App.xcconfig`, select `WallpaperSwap-iCloud.entitlements` instead of the Paid file. That file is the App Group plus CloudKit. The widget does not get iCloud.
3. Use a paid team. In Signing & Capabilities for the app target, confirm iCloud is on, CloudKit is checked, and the container is `iCloud.app.wallpaperswap.ios`. If you pick a different container, set `CLOUDKIT_CONTAINER_ID` in `Config/Identifiers.xcconfig` to the same string.
4. Run the app once from Xcode and create a code in **iCloud** mode. That creates the `Room` and `Photo` record types in the development database.
5. Open the [CloudKit Console](https://icloud.developer.apple.com/dashboard), choose the container, Development, and Schema. Add a **Queryable** index on `Photo.room`. The Room and Guest records are fetched by id, so they don't need an index. Save, then deploy the schema to Production before you ship a TestFlight build that uses iCloud.
6. Both people choose iCloud in the app, and both phones are signed into iCloud.

Until the entitlement and the index exist, the app stays usable. iCloud actions fail with a message that says so, and Nearby is still there.

There is no Firebase project and no API key. CloudKit is the optional backend because a paid Apple team can turn it on from Xcode without a separate account.

## Set the real wallpaper

The Guide tab has this in the app. Short version:

1. Open Wallpaper Swap once so iOS indexes the action. If Shortcuts can't find it, force-quit Shortcuts and open it again.
2. In Shortcuts, make a new shortcut. Add **Get Latest Wallpaper** (under Wallpaper Swap), then add **Set Wallpaper**.
3. Tap the photo on Set Wallpaper and choose the **Latest Wallpaper** variable from the previous action.
4. Open Set Wallpaper's details, turn off **Show Preview**, and choose Lock Screen, Home Screen, or Both.
5. If that photo field is greyed out, set any photo as your wallpaper in the Settings app once, then come back and pick the variable.
6. Run the shortcut and approve the prompts.
7. To run it when a photo arrives: Automation → App → Wallpaper Swap → Is Opened → Run Immediately, and run this shortcut. iOS may still ask the first time. You can also add the shortcut to the Home Screen and tap it.

Adding the widgets: touch and hold the Home Screen, tap +, and search for Wallpaper Swap. The large widget is the one that feels most like a wallpaper. On the Lock Screen, touch and hold, tap Customize, then Lock Screen, and add the rectangular or circular widget. Lock Screen widgets can pick up the system's tint. The Shortcut is what changes the wallpaper behind the clock.

## Move it to TestFlight

TestFlight needs the paid Apple Developer Program. A free Apple ID cannot upload a build.

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs).
2. Turn on the Paid entitlements (and the iCloud file, if you want that mode in the beta). Confirm the bundle id in `Config/Identifiers.xcconfig` is the one you want on the store. You cannot change it later for that App Store record.
3. In App Store Connect, create an iOS app with that bundle id. The widget does not get its own App Store record. It is inside the app.
4. In Xcode, set the destination to **Any iOS Device (arm64)**, not a simulator. Product → Archive.
5. In the Organizer, Distribute App → App Store Connect → Upload. Automatic signing is enough on a paid team. Xcode creates the distribution profiles for the app and the extension.
6. Export compliance is already answered in the project (`ITSAppUsesNonExemptEncryption` is false). The app does not add its own encryption. Nearby uses the system's Multipeer encryption, and iCloud uses Apple's.
7. Privacy nutrition label: with only "This iPhone" and Nearby, you can answer **Data Not Collected**. The app does not run a server of its own. If testers use iCloud mode, photos are stored in your CloudKit public database, so declare Photos as data stored in iCloud and not used for tracking. There is a privacy manifest in the app and the widget.
8. Internal TestFlight is available to people on your App Store Connect team as soon as the build finishes processing. External testing needs Beta App Review.
9. Testers install Apple's TestFlight app and accept the invite. Builds there last 90 days, which is the usual reason to leave the 7-day free profile behind.

## Project layout

```
Config/                         bundle ids, and which entitlements are signed
Shared/                         models and the photo store, compiled into the app and the widget
WallpaperSwap/                  the iOS app
WallpaperSwapWidget/            the widget extension
WallpaperSwap.xcodeproj         open this
project.yml                     optional XcodeGen spec
```

The photo store writes into the App Group container when that entitlement is signed, and into Application Support otherwise. The widget only reads `current.jpg`. The Shortcut action reads the same file from inside the app, which is why it works without the group.

## Troubleshooting

**Signing for "WallpaperSwap" requires a development team.**  
Select your Personal Team on both the app target and the WallpaperSwapWidget target.

**Personal development teams do not support the App Groups capability.**  
Or the same sentence about iCloud. You are signing a Paid or iCloud entitlements file with a free team. Put the Free lines back in `Config/App.xcconfig` and `Config/Widget.xcconfig`.

**The app identifier cannot be registered to your development team.**  
Change `APP_BUNDLE_IDENTIFIER` in `Config/Identifiers.xcconfig`.

**The widget is installed but never shows the photo.**  
Expected on a free team. Use the Shortcut, or turn on the App Group with a paid account. Settings → Widget sharing tells you which case you're in.

**Nearby can't find the code.**  
Both apps have to be open, on the same Wi-Fi, and the phone has to have allowed local network access. The first Nearby attempt prompts for that.

**iCloud says the query was rejected.**  
Add the Queryable index on `Photo.room` in the CloudKit console. Development and Production are separate.

**The app opens and then dies a week later.**  
The free profile expired. Connect the phone and press Run.

## What this can't do

An app still cannot set the Lock Screen or Home Screen wallpaper by itself. The Shortcut is the supported way, and iOS may ask the first time it runs. Nearby does not deliver in the background. The history keeps the most recent 80 photos. One friend at a time.
