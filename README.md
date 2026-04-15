# ADHDFocus

A Pomodoro-style focus timer for Sailfish OS, designed for people with ADHD.

## Features

- **Two modes:** 25/5 and 50/10
- **Arc timer** with fade-in/fade-out phases (30s prelude, 10s winddown)
- **Brown noise** bed during focus, pings at phase boundaries
- **Task list:** up to three tasks per session, carry-over of unfinished tasks
- **+5 min extension** once per session
- **Screen kept awake** while a session is running

## Stack

- Qt5 / QML, Sailfish.Silica
- `SessionEngine.qml` singleton holds all session state
- qmake build, packaged as RPM

## Build

Requires the Sailfish SDK.

```bash
sfdk build
```

Produces `RPMS/ADHDFocus-<version>-1.aarch64.rpm`.

## Target

SailfishOS 5.x, aarch64.

## License

GPLv3 — see [LICENSE](LICENSE).
