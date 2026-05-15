pragma Singleton
import QtQuick 2.6

// SessionEngine
// =============
// Central session state machine, exposed as a QML singleton (`import engine
// 1.0`). It owns *all* time-related state for the session; pages and the
// root window react to its properties via bindings and to `phaseChanged`
// via Connections.
//
// One session loops through these phases:
//
//   idle -> prelude -> focus -> winddown -> break -> prelude -> ... -> end
//
//   prelude   : a 30-second fade-in window during which the user can add
//               up to 3 tasks. Audio brown-noise starts here.
//   focus     : the actual work interval (25 or 50 minutes depending on mode).
//   winddown  : a 10-second fade-out window; the +5 min extension is
//               offered here.
//   break     : 5 or 10 minutes of pause.
//   end       : the session is complete; the recap page takes over.
//
// All `*Seconds` properties below are *named constants*. They are
// `readonly` so the runtime cannot reassign them by accident. Treat them
// as the single source of truth for these magic numbers.
QtObject {

    // --- Named constants for the magic numbers used by the state machine.
    readonly property int preludeSeconds: 30    // fade-in window length
    readonly property int winddownSeconds: 10   // fade-out window length
    readonly property int extensionSeconds: 300 // length of the +5 min extension
    readonly property int maxTasks: 3           // limit enforced by addTask()

    // --- Configuration: mode and the derived focus/break durations (seconds).
    // Both durations are 0 until init() picks them based on `mode`.
    property string mode: "25/5"
    property int focusDuration: 0
    property int breakDuration: 0

    // --- Runtime state.
    property int remainingTotal: 0   // seconds of focus+break time left in session
    property int remainingPhase: 0   // seconds left in the current focus or break

    property string phase: "idle"    // idle | prelude | focus | winddown | break | end
    property bool isRunning: false
    property int preludeRemaining: 0  // current prelude countdown
    property int winddownRemaining: 0 // current winddown countdown

    property bool extensionUsed: false // the +5 min extension is one-shot per session

    // True for exactly one transition: when requestExtension() jumps directly
    // from winddown to focus. The audio handler reads this to know it needs to
    // restart the brown-noise bed (which had just faded out). Cleared by
    // startFocus() the next time we enter focus the normal way.
    property bool focusFromExtension: false

    // --- Task list (capped at maxTasks in addTask()); each entry has the
    // shape { title: string, completed: bool }.
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

    // --- Prelude: fade-in during which the user adds tasks.
    function startPrelude() {
        phase = "prelude"
        preludeRemaining = preludeSeconds
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

    // --- Winddown: fade-out at the end of each focus interval; +5 min offered here.
    function startWinddown() {
        phase = "winddown"
        winddownRemaining = winddownSeconds
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

    // --- Break: pause; loops back into prelude when done.
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
    // back into focus (skipping prelude), and flags focusFromExtension so
    // the audio bed can be restarted by the view.
    function requestExtension() {
        if (extensionUsed)
            return false

        remainingTotal += extensionSeconds
        extensionUsed = true
        focusFromExtension = true
        remainingPhase = extensionSeconds
        phase = "focus"   // emits phaseChanged last, after all state is in place
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

    // --- Task helpers. We *reassign* `tasks` (rather than push/mutate in
    // place) because QML property bindings only fire when the property is
    // assigned a new value, not when an array's contents change.
    function addTask(title) {
        if (!title || tasks.length >= maxTasks) return
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
