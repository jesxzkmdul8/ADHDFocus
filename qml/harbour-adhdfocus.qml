import QtQuick 2.6
import Sailfish.Silica 1.0
import QtMultimedia 5.6
import Nemo.KeepAlive 1.2
import engine 1.0

// Root window. Drives the per-second session clock, plays audio in reaction to
// engine phase changes, and hosts the page stack. Pages navigate themselves by
// observing SessionEngine.phase via their own Connections blocks.
ApplicationWindow {
    id: window

    allowedOrientations: Orientation.All
    initialPage: Qt.resolvedUrl("pages/SetupView.qml")
    cover: Qt.resolvedUrl("cover/CoverPage.qml")

    // Keep the screen awake while a session is running.
    DisplayBlanking {
        preventBlanking: SessionEngine.isRunning
    }

    // --- Brown noise bed played during focus phases.
    // 55-minute file on disk (longer than any single focus phase, so no loop mid-focus).
    // Volume is animated via the Behavior; duration is set per-transition (30s in, 10s out).
    Audio {
        id: brownNoise
        source: dataDir + "sounds/brown_noise.ogg"
        loops: Audio.Infinite
        volume: 0.0
        autoLoad: true
        Behavior on volume { id: volumeFade; NumberAnimation { id: volumeAnim; duration: 30000 } }
    }

    // --- Short cues at phase boundaries.
    Audio {
        id: pingStart
        source: dataDir + "sounds/ping_start.wav"
        volume: 0.6
    }

    Audio {
        id: pingEnd
        source: dataDir + "sounds/ping_end.wav"
        volume: 0.6
    }

    // --- Session clock. Ticks once per second while a session is running and
    // advances the engine. The engine itself emits phaseChanged whenever a tick
    // moves it into a new phase; audio transitions are wired off that signal
    // (below), not off the timer, so each transition's sound fires exactly once.
    Timer {
        interval: 1000
        running: SessionEngine.isRunning
        repeat: true

        onTriggered: {
            if (SessionEngine.phase === "prelude")
                SessionEngine.tickPrelude()
            else if (SessionEngine.phase === "focus")
                SessionEngine.tickFocus()
            else if (SessionEngine.phase === "winddown")
                SessionEngine.tickWinddown()
            else if (SessionEngine.phase === "break")
                SessionEngine.tickBreak()
        }
    }

    // --- Audio reactions. One handler per phase entry; fires exactly once per
    // change because phaseChanged only emits when the value actually differs.
    Connections {
        target: SessionEngine

        onPhaseChanged: {
            if (SessionEngine.phase === "prelude") {
                // Entering a new focus block: start brown noise at 0, fade in over 30s.
                volumeFade.enabled = false
                brownNoise.volume = 0.0
                brownNoise.play()
                volumeAnim.duration = 30000
                volumeFade.enabled = true
                brownNoise.volume = 0.3
            }
            else if (SessionEngine.phase === "focus") {
                pingStart.play()
                if (SessionEngine.focusFromExtension) {
                    // +5 min jumped straight from winddown; the previous
                    // winddown faded the bed to 0. Restart it here so the
                    // extension isn't silent.
                    volumeFade.enabled = false
                    brownNoise.volume = 0.0
                    brownNoise.play()
                    volumeAnim.duration = 30000
                    volumeFade.enabled = true
                    brownNoise.volume = 0.3
                }
            }
            else if (SessionEngine.phase === "winddown") {
                // End-of-focus cue plus 10s brown-noise fade-out.
                pingEnd.play()
                volumeAnim.duration = 10000
                brownNoise.volume = 0.0
            }
            else if (SessionEngine.phase === "break" || SessionEngine.phase === "end") {
                // Cut audio cleanly at break/end (volume already near zero from winddown).
                volumeFade.enabled = false
                brownNoise.stop()
                brownNoise.volume = 0.0
                volumeFade.enabled = true
            }
        }
    }
}
