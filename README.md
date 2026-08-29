# CmdTab

A macOS app switcher that replaces Cmd+Tab — same behavior, plus numbers.

![CmdTab switcher](docs/image.png)

## What's different from the native switcher

- Every app shows a number (**1–9**). Hold **Cmd** and press a number to jump straight to that app.
- Opens on the screen of the **current app**, so it always appears where you're working.

Everything else is the native switcher: most-recently-used order, #2 pre-focused, **Tab** / **Shift+Tab** to cycle, release **Cmd** to switch, **Esc** or click outside to cancel.

## Setup

Requires **Input Monitoring** and **Accessibility** permissions — macOS prompts on first launch (missed them? menu bar icon → **Open Permissions…**).

```sh
./build.sh   # builds dist/CmdTab.app
./run.sh     # launches it
```

## Debugging

Menu bar icon → **Debug Logging** (default off) writes to `~/tmp/cmd-tab/log`.

## Limitations

- Lists the 9 most-recently-used apps that have on-screen windows.
- Holding **Cmd** alone for >1s can still trigger the native switcher; **Cmd+Tab** is unaffected.
