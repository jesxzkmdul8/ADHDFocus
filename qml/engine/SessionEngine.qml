pragma Singleton
import QtQuick 2.6

// Central session state machine. Singleton; all durations in seconds.
// Phases: idle -> prelude -> focus -> winddown -> break -> prelude -> ... -> end
QtObject {

    // --- Configuration: mode and the derived focus/break durations (seconds).
    // Both durations are 0 until init() picks them based on `mode`.
    property string mode: "25/5"
    property int focusDuration: 0
    property int breakDuration: 0

    // --- Runtime state.
    property int remainingTotal: 0  // seconds of focus+break time left in session
    property int remainingPhase: 0  // seconds left in the current focus or break

    property string phase: "idle"   // idle | prelude | focus | winddown | break | end
    property bool isRunning: false
    property int preludeRemaining: 0   // fade-in countdown (30s)
    property int winddownRemaining: 0  // fade-out countdown (10s)

    property bool extensionUsed: false // +5 min extension is one-shot per session

    // True for exactly one transition: when requestExtension() jumps directly
    // from winddown to focus. The audio handler reads this to know it needs
    // to restart the brown-noise bed (which had just faded out). Cleared by
    // startFocus() the next time we enter focus the normal way.
    property bool focusFromExtension: false

    // --- Task list (max 3 in UI); each entry: { title, completed }.
    property var tasks: []

    // --- Setup: called by SetupView before start(). Resets state and applies mode.
    function init(totalSeconds, selectedMode, taskList) {
        mode = selectedMode
        tasks = taskList

        remainingTotal = totalSeconds
        extensionUsed = false
        focusFromExtension = false
        phase = "idle"
        isRunning = false

        if (mode === "25/5") {
            focusDuration = 25 * 60
            breakDuration = 5 * 60
        } else {
            focusDuration = 50 * 60
            breakDuration = 10 * 60
        }
    }

    // --- Entry point: begin the session with the fade-in prelude.
    function start() {
        isRunning = true
        startPrelude()
    }

    // --- Prelude: 30s fade-in during which the user adds tasks.
    function startPrelude() {
        phase = "prelude"
        preludeRemaining = 30
    }

    function tickPrelude() {
        preludeRemaining--
        if (preludeRemaining <= 0)
            startFocus()
    }

    // --- Focus: the actual work interval (25 or 50 minutes).
    function startFocus() {
        focusFromExtension = false
        phase = "focus"
        remainingPhase = focusDuration
    }

    function tickFocus() {
        remainingPhase--
        remainingTotal--

        // Either condition ends the focus block; combined so we don't enter
        // winddown twice on the tick where both reach zero simultaneously.
        if (remainingPhase <= 0 || remainingTotal <= 0)
            startWinddown()
    }

    // --- Winddown: 10s fade-out at the end of each focus interval; +5 min offered here.
    function startWinddown() {
        phase = "winddown"
        winddownRemaining = 10
    }

    function tickWinddown() {
        winddownRemaining--
        if (winddownRemaining <= 0) {
            if (remainingTotal <= 0)
                endSession()
            else
                startBreak()
        }
    }

    // --- Break: 5 or 10 minutes of pause; loops back into prelude when done.
    function startBreak() {
        phase = "break"
        remainingPhase = breakDuration
    }

    function tickBreak() {
        remainingPhase--
        remainingTotal--

        if (remainingTotal <= 0) {
            endSession()
            return
        }

        if (remainingPhase <= 0) {
            // Drop completed tasks so the next focus starts with a clean list.
            tasks = tasks.filter(function(t) { return !t.completed })
            startPrelude()
        }
    }

    // --- +5 min extension: one-shot, used during winddown. Jumps straight
    // back into focus (skipping prelude). Sets focusFromExtension so the view
    // can restart audio that the winddown had faded out. All state is in
    // place before `phase` is assigned, so consumers of phaseChanged see a
    // fully consistent engine.
    function requestExtension() {
        if (extensionUsed)
            return false

        remainingTotal += 300
        extensionUsed = true
        focusFromExtension = true
        remainingPhase = 300
        phase = "focus"
        return true
    }

    // --- End of session: enter the recap/reentry screen.
    function endSession() {
        phase = "end"
        isRunning = false
    }

    // --- Hard reset (called by "New session" button on the recap screen).
    function reset() {
        phase = "idle"
        isRunning = false
        remainingTotal = 0
        remainingPhase = 0
        preludeRemaining = 0
        winddownRemaining = 0
        tasks = []
        extensionUsed = false
        focusFromExtension = false
    }

    // --- Task helpers. Reassigning tasks (vs push) is required for QML bindings to fire.
    function addTask(title) {
        if (!title || tasks.length >= 3) return
        var t = tasks.slice()
        t.push({ title: title, completed: false })
        tasks = t
    }

    function toggleTask(index) {
        if (!tasks[index]) return
        var t = tasks.slice()
        t[index] = { title: t[index].title, completed: !t[index].completed }
        tasks = t
    }
}
