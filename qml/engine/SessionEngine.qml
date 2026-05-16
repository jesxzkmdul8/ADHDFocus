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
//   winddown  : a 10-second fade-out window.
//   break     : 5 or 10 minutes of pause.
//
// The +5 min extension is offered in two 15 s windows per cycle: 1.5 min
// before the end of the focus phase, and 1.5 min before the end of the
// break. Clicking the button always jumps into a fresh 5 min focus block.
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

    // --- Task list (capped at maxTasks in addTask()); each entry has the
    // shape { title: string, completed: bool }.
    property var tasks: []

    // --- Setup: called by SetupView before start(). Resets state and applies mode.
    function init(totalSeconds, selectedMode, taskList) {
        mode = selectedMode
        tasks = taskList

        remainingTotal = totalSeconds
        phase = "idle"
        isRunning = false

        if (mode === "25/5") {
            focusDuration = 25 * 60
            breakDuration = 5 * 60
        } else if (mode === "50/10") {
            focusDuration = 50 * 60
            breakDuration = 10 * 60
        } else if (mode === "5/5") {
            // --- DEV/TEST MODE ---
            // Short cycles for quick manual testing. Exposed in SetupView
            // when its _testModesEnabled flag is true. Delete both this
            // branch and the matching entry in SetupView._availableModes
            // once no longer needed.
            focusDuration = 5 * 60
            breakDuration = 5 * 60
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

    // --- +5 min extension: offered 1.5 min before the end of focus and
    // again 1.5 min before the end of break (see FocusView / BreakView).
    // Extends the *current* phase in place — tapping during focus adds
    // 5 min of focus, tapping during break adds 5 min of break. No phase
    // transition is triggered.
    //
    // The extension does *not* grow remainingTotal: the 5 extra minutes
    // come out of the existing session budget. The natural consequence
    // is that a later cycle gets shortened — tickFocus / tickWinddown /
    // tickBreak all watch for remainingTotal <= 0 and end the session
    // cleanly when it runs out. Overall session duration stays exactly
    // what the user picked on the setup screen. The user can chain
    // extensions (each visibility window can fire once) until the budget
    // runs low.
    function requestExtension() {
        if (phase !== "focus" && phase !== "break")
            return false
        if (remainingTotal <= 0)
            return false   // no budget left to borrow from

        // Cap the new phase length to what's left in the session budget,
        // so we never schedule more focus/break than the session can
        // actually deliver.
        remainingPhase = Math.min(remainingPhase + extensionSeconds, remainingTotal)
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
