# CmdTab

A macOS app switcher that replaces Cmd+Tab — same behavior, plus numbers.

![CmdTab switcher](docs/image.png)

## What's different from the native switcher

- Every app shows a number (**1–9**). Hold **Cmd** and press a number to jump straight to that app.
- Opens on the screen of the **current app**, so it always appears where you're working.

Everything else is the native switcher: most-recently-used order, #2 pre-focused, **Tab** / **Shift+Tab** to cycle, release **Cmd** to switch, **Esc** or click outside to cancel.

## Install

### Download (easiest)

Grab the latest `CmdTab.dmg` from [Releases](https://github.com/sonht1109/CmdTab/releases), drag **CmdTab** into Applications, and launch it.

> First launch: right-click → **Open** → **Open** (releases aren't Apple-notarized yet). Then grant **Input Monitoring** and **Accessibility** — macOS prompts on first launch (missed them? menu bar icon → **Open Permissions…**).

### Build from source

```sh
./build.sh   # builds dist/CmdTab.app
./run.sh     # launches it
```

## Releasing

Push a version tag and CI does the rest — builds a universal (Intel + Apple Silicon) app, signs it, and attaches `CmdTab.dmg` + `CmdTab.zip` to a GitHub Release:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

Until Apple Developer ID secrets are added, releases are **ad-hoc signed and not notarized**, so users see a Gatekeeper warning on first launch. To get a clean install, add these repo secrets (requires an Apple Developer account) — the workflow enables signing/notarization automatically once they exist:

- `APPLE_CERT_BASE64` — Developer ID Application certificate + private key, exported as `.p12` and base64-encoded
- `APPLE_CERT_PASSWORD` — the `.p12` password
- `APPLE_ID` / `APPLE_TEAM_ID` / `APPLE_APP_PASSWORD` — App Store Connect credentials for `notarytool`

## Debugging

Menu bar icon → **Debug Logging** (default off) writes to `~/tmp/cmd-tab/log`.

## Limitations

- Lists the 9 most-recently-used apps that have on-screen windows.
- Holding **Cmd** alone for >1s can still trigger the native switcher; **Cmd+Tab** is unaffected.
