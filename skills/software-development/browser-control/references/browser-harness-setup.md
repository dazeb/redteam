# browser-harness setup notes

Session-derived setup detail for browser-harness / real-browser attachment.

## Durable checkout + editable install
- Clone the repo to a stable path, then install editable so local changes are picked up immediately:
  - `git clone https://github.com/browser-use/browser-harness`
  - `cd browser-harness`
  - `uv tool install -e .`
  - `command -v browser-harness`

## Real-browser attach on WSL/Windows
- If Chrome is already running but `browser-harness --doctor` shows `chrome running` and `daemon alive` fails, the usual cause is that remote debugging is not enabled for the running Chrome profile.
- From WSL, opening the inspect page in the Windows Chrome instance works reliably when launched via PowerShell from a local Windows path, not a UNC path.
- Example:
  - workdir: `/mnt/c/Users/dbenn`
  - command: `powershell.exe -NoProfile -Command "Start-Process chrome.exe 'chrome://inspect/#remote-debugging'"`

## User action required
- Ask the user to tick `Allow remote debugging for this browser instance`.
- If Chrome shows the in-browser `Allow remote debugging?` popup, the user must click Allow.

## Verification cues
- `browser-harness --doctor` is the fastest triage command.
- If attach succeeds, `browser-harness -c 'print(page_info())'` should return page info.
- If a setup or verification tab is opened, switch to it so the user can see the active tab.

## Failure signature seen in this session
- `fatal: DevToolsActivePort not found ... enable chrome://inspect/#remote-debugging, or set BU_CDP_WS for a remote browser`

## Notes
- The browser-harness docs warn that CDP target order can differ from the visible Chrome tab strip; use `switch_tab()` when the visible tab matters.
- For first navigation in a fresh tab, prefer `new_tab(url)` and then verify with a screenshot or `page_info()`.
