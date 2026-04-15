import QtQuick 2.6
import Sailfish.Silica 1.0
import QtMultimedia 5.6
import Nemo.KeepAlive 1.2
import engine 1.0

// Root window. Drives the session clock and audio; pages navigate themselves
// by observing SessionEngine.phase.
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
        source: "file:///usr/share/ADHDFocus/sounds/brown_noise.ogg"
        loops: Audio.Infinite
        volume: 0.0
        autoLoad: true
        Behavior on volume { id: volumeFade; NumberAnimation { id: volumeAnim; duration: 30000 } }
    }

    // --- Short cues at phase boundaries.
    Audio {
        id: pingStart
        source: "file:///usr/share/ADHDFocus/sounds/ping_start.wav"
        volume: 0.6
    }

    Audio {
        id: pingEnd
        source: "file:///usr/share/ADHDFocus/sounds/ping_end.wav"
        volume: 0.6
    }

    // --- Session clock. Ticks once per second while a session is running, advances
    // the engine, and fires audio on phase transitions (guarded by _lastPhase so each
    // transition's sound happens exactly once).
    property string _lastPhase: "idle"

    Timer {
        interval: 1000
        running: SessionEngine.isRunning
        repeat: true

        onTriggered: {
            // Tick the engine based on the current phase.
            var phaseBefore = SessionEngine.phase

            if (phaseBefore === "prelude")
                SessionEngine.tickPrelude()
            else if (phaseBefore === "focus")
                SessionEngine.tickFocus()
            else if (phaseBefore === "winddown")
                SessionEngine.tickWinddown()
            else if (phaseBefore === "break")
                SessionEngine.tickBreak()

            // React to any phase change with the matching audio transition.
            var phaseAfter = SessionEngine.phase

            if (phaseAfter !== _lastPhase) {
                if (phaseAfter === "prelude") {
                    // Entering a new focus block: start brown noise at 0, fade in over 30s.
                    volumeFade.enabled = false
                    brownNoise.volume = 0.0
                    brownNoise.play()
                    volumeAnim.duration = 30000
                    volumeFade.enabled = true
                    brownNoise.volume = 0.3
                }
                else if (phaseAfter === "focus") {
                    pingStart.play()
                }
                else if (phaseAfter === "winddown") {
                    // End-of-focus cue plus 10s brown-noise fade-out.
                    pingEnd.play()
                    volumeAnim.duration = 10000
                    brownNoise.volume = 0.0
                }
                else if (phaseAfter === "break" || phaseAfter === "end") {
                    // Cut audio cleanly at break/end (volume already near zero from winddown).
                    volumeFade.enabled = false
                    brownNoise.stop()
                    brownNoise.volume = 0.0
                    volumeFade.enabled = true
                }

                _lastPhase = phaseAfter
            }
        }
    }
}
