# StackRails plugin install matrix (staging, QA org)

Target: `https://mcp.stage.stackrails.ai` (staging). Use the QA org only.
Status values: `NOT RUN`, `PASS`, `FAIL`, `BLOCKED` (add the reason in the note).
Record per case: host + version, model, OS, status, note or screenshot.
Each `FAIL` gets a subtask under the parent ticket.

Local environment on the test machine (Fedora 42, x86_64): Claude Code 2.1.325, Python 3.11 and 3.13 present, **Python 3.12 missing**.

## A. Install paths

| ID | Case | Host + version | Model | OS | Status | Note |
|---|---|---|---|---|---|---|
| A1 | Marketplace install via `/plugin`: plugin installs and shows enabled | | | Linux | NOT RUN | |
| A2 | Marketplace install: next session's SessionStart banner appears once | | | Linux | NOT RUN | |
| A3 | Customer zip install, per `docs/customer-install.md` | | | Linux | NOT RUN | Confirm the doc exists in the plugin package first |
| A4 | Installer, local scope: files land in `./.claude`, `settings.json` registers each hook once | | | Linux | NOT RUN | |
| A5 | Installer, global scope (`~/.claude`): same checks as A4 | | | Linux | NOT RUN | Changes the user's global config; use a scratch account or back up `~/.claude` first |
| A6 | Local then global in one project: hooks run twice? Duplicate banner = known gap #18 | | | Linux | NOT RUN | Expected to show the gap; record the result either way |
| A7 | Local install where `.claude` links to `~/.claude` is refused with a clear message | | | Linux | NOT RUN | |
| A8 | Reinstall over an older version: no duplicate hooks, user settings kept | | | Linux | NOT RUN | |
| A9 | Uninstall: StackRails hooks, skills and commands removed; user's own settings kept | | | Linux | NOT RUN | |

## B. Operating systems

| ID | Case | Host + version | Model | OS | Status | Note |
|---|---|---|---|---|---|---|
| B1 | Full A-series run on Windows, PowerShell | | | Windows | NOT RUN | Machine not available here |
| B2 | Full A-series run on Windows, Git Bash | | | Windows | NOT RUN | Machine not available here |
| B3 | Full A-series run on macOS | | | macOS | NOT RUN | Machine not available here |
| B4 | Full A-series run on Linux | | | Linux | NOT RUN | Available here |

## C. Python versions

| ID | Case | Host + version | Model | OS | Status | Note |
|---|---|---|---|---|---|---|
| C1 | Hooks work on Python 3.11 | | | Linux | NOT RUN | `/usr/bin/python3.11` present |
| C2 | Hooks work on Python 3.12 | | | Linux | BLOCKED | Python 3.12 not installed on the test machine |
| C3 | Hooks work on Python 3.13 | | | Linux | NOT RUN | `/usr/bin/python3.13` present |
| C4 | No Python 3 on PATH: hooks print one clear line and block nothing | | | Linux | NOT RUN | Run with PATH stripped of python |

## D. Paths

| ID | Case | Host + version | Model | OS | Status | Note |
|---|---|---|---|---|---|---|
| D1 | Install path containing spaces works on Windows | | | Windows | NOT RUN | |
| D2 | Install path with non-ASCII characters (e.g. `café`) works on Windows | | | Windows | NOT RUN | |

## Open items

- The test machine has an existing `.claude/stackrails` folder in the project dated 16 Nov. Decide whether to remove it before running A4 so the install starts clean.
- Staging sign-in for the plugin uses OAuth in the browser, so each run needs someone at the browser.
- Test with the QA org only; do not use production.
