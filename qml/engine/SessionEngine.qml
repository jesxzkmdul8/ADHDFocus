pragma Singleton
import QtQuick 2.6

// Central session state machine. Singleton; all durations in seconds.
// Phases: idle -> prelude -> focus -> winddown -> break -> prelude -> ... -> end
QtObject {

    // --- Configuration: total length and derived focus/break durations.
    property int totalTime: 0       // seconds of focused work requested by user
    property string mode: "25/5"

    property int focusDuration: 25  // seconds (rewritten by init() based on mode)
    property int breakDuration: 5

    // --- Runtime state.
    property int remainingTotal: 0  // seconds of focus+break time left in session
    property int remainingPhase: 0  // seconds left in the current focus or break

    property string phase: "idle"   // idle | prelude | focus | winddown | break | end
    property bool isRunning: false
    property int preludeRemaining: 0   // fade-in countdown (30s)
    property int winddownRemaining: 0  // fade-out countdown (10s)

    property bool extensionUsed: false // +5 min extension is one-shot per session

    // --- Task list (max 3 in UI); each entry: { title, completed }.
    property var tasks: []

    // --- Setup: called by SetupView before start(). Resets state and applies mode.
    function init(totalSeconds, selectedMode, taskList) {
        totalTime = totalSeconds
        mode = selectedMode
        tasks = taskList

        remainingTotal = totalSeconds
        extensionUsed = false
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
        phase = "focus"
        remainingPhase = focusDuration
    }

    function tickFocus() {
        remainingPhase--
        remainingTotal--

        if (remainingPhase <= 0)
            startWinddown()

        if (remainingTotal <= 0)
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

    // --- +5 min extension: one-shot, used during winddown. Jumps back into focus.
    function requestExtension() {
        if (extensionUsed)
            return false

        remainingTotal += 300
        extensionUsed = true
        phase = "focus"
        remainingPhase = 300
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
