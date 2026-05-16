import QtQuick 2.6
import Sailfish.Silica 1.0
import engine 1.0

// FocusView
// =========
// The page that covers three engine phases:
//   - prelude   : circular fade-in countdown + text fields for new tasks
//   - focus     : circular work countdown + interactive task list
//   - winddown  : fade-out countdown + a one-shot "+5 min" button
//
// Navigation off this page is signal-driven via the Connections block below,
// not polled — when the engine moves into "break" or "end", we replace the
// page synchronously.
//
// Naming convention: properties whose name starts with an underscore (`_`)
// are view-local state — they exist only to track UI bookkeeping (typed-but-
// unsubmitted text, etc.). Anything without the prefix is part of the page's
// public surface.
Page {
    id: focusPage

    // --- Visual constants. Defined here so a reader can change the palette
    // in one place instead of hunting through the Canvas code below.
    readonly property color colorFade: "#ffaa00"   // orange: prelude + winddown arcs
    readonly property color colorFocus: "#00aaff"  // blue:   focus arc
    readonly property color colorRing: "#333333"   // background ring of the arc

    // Duration of the "25 min" / "50 min" hint flash, and its fade animation.
    readonly property int hintHoldMs: 15000
    readonly property int hintFadeMs: 1500

    // Buffers for the up-to-3 editable prelude task fields. Written by
    // `onTextChanged` on each field, drained when the engine leaves prelude.
    property var _taskTexts: ["", "", ""]

    // --- Engine reactions.
    //
    // `Connections` listens for signals on another object — here, the engine's
    // automatic `phaseChanged` signal (every QML property has one). The body
    // runs whenever SessionEngine.phase is set to a different value.
    Connections {
        target: SessionEngine

        onPhaseChanged: {
            if (SessionEngine.phase === "focus") {
                // Show the "25 min" / "50 min" reminder, then fade it out.
                durationHint.opacity = 1.0
                hintTimer.restart()

                // Prelude just ended: push whatever the user typed in the
                // editable slots into the engine's task list.
                var slots = SessionEngine.maxTasks - SessionEngine.tasks.length
                for (var i = 0; i < slots; i++) {
                    var t = focusPage._taskTexts[i].trim()
                    if (t.length > 0)
                        SessionEngine.addTask(t)
                }
                focusPage._taskTexts = ["", "", ""]
            }
            else if (SessionEngine.phase === "break") {
                pageStack.replace(Qt.resolvedUrl("BreakView.qml"))
            }
            else if (SessionEngine.phase === "end") {
                pageStack.replace(Qt.resolvedUrl("ReentryView.qml"))
            }
        }
    }

    // --- Top half: circular arc timer.
    Item {
        id: arcArea
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.height / 2

        // Arc-progress canvas. Both the colour and the angular extent depend
        // on the current phase:
        //   prelude / winddown -> orange, a fixed 120° wedge that shrinks
        //                          with the remaining fade time
        //   focus              -> blue,   a wedge whose full size scales
        //                          with focusDuration (360° for 60 min)
        Canvas {
            id: arcCanvas
            width: Math.min(parent.width, parent.height) * 0.85
            height: width
            anchors.centerIn: parent

            // Fraction of the wedge still to draw, clamped to [0, 1]. The
            // clamp guards against values briefly going out of range when
            // the engine ticks faster than the canvas repaints, and the
            // explicit branch guards against focusDuration == 0 in idle.
            property real progress: {
                var raw
                if (SessionEngine.phase === "prelude")
                    raw = SessionEngine.preludeRemaining / SessionEngine.preludeSeconds
                else if (SessionEngine.phase === "winddown")
                    raw = SessionEngine.winddownRemaining / SessionEngine.winddownSeconds
                else if (SessionEngine.focusDuration > 0)
                    raw = SessionEngine.remainingPhase / SessionEngine.focusDuration
                else
                    raw = 0
                return Math.max(0, Math.min(1, raw))
            }

            // Full-wedge angular size in degrees. Fixed at 120° for the
            // fades; scaled by focus length for focus (60 s -> 6°, 25 min ->
            // 150°, 50 min -> 300°, 60 min -> 360°).
            property real startAngle: (SessionEngine.phase === "prelude" || SessionEngine.phase === "winddown")
                ? 120
                : SessionEngine.focusDuration / 10

            onPaint: {
                // HTML5-Canvas API. Coordinates: (0,0) is the top-left of the
                // canvas; we draw the arc centred at (cx, cy).
                var ctx = getContext("2d");
                ctx.reset();

                var cx = width / 2;
                var cy = height / 2;
                var lw = width / 20;     // ring thickness, ~5% of width
                var r = width / 2 - lw;  // radius, leaving room for the line

                // Background ring (always full circle, dim).
                ctx.beginPath();
                ctx.lineWidth = lw;
                ctx.strokeStyle = focusPage.colorRing;
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.stroke();

                // Foreground progress arc. Canvas measures angles in
                // *radians* and 0 rad points right (3 o'clock). We want the
                // wedge to start at 12 o'clock, so we offset by -π/2.
                var endAngleDeg = startAngle * progress;
                var endAngleRad = endAngleDeg * Math.PI / 180;

                ctx.beginPath();
                ctx.lineWidth = lw;
                ctx.strokeStyle = (SessionEngine.phase === "prelude" || SessionEngine.phase === "winddown")
                    ? focusPage.colorFade
                    : focusPage.colorFocus;

                ctx.arc(
                    cx, cy, r,
                    -Math.PI / 2,                  // start: 12 o'clock
                    -Math.PI / 2 + endAngleRad,    // end:   wedge clockwise
                    false
                );
                ctx.stroke();
            }

            // The Canvas doesn't auto-repaint when properties change — we
            // poke it once a second, which is plenty for a minute-scale timer.
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: arcCanvas.requestPaint()
            }
        }

        // --- Duration hint centred in the arc: "25 min" on entering focus,
        // fades to invisible after hintHoldMs.
        Label {
            id: durationHint
            anchors.centerIn: arcCanvas
            // During the +5 min extension the focus block is at most
            // extensionSeconds (and often less, capped by remainingTotal),
            // not focusDuration — so the normal "25 min" / "50 min" hint
            // would be misleading. Show "+5 min" instead until the engine
            // re-enters focus the normal way and clears focusFromExtension.
            text: SessionEngine.focusFromExtension
                  ? qsTr("+5 min")
                  : SessionEngine.focusDuration >= 60
                    ? qsTr("%1 min").arg(Math.round(SessionEngine.focusDuration / 60))
                    : qsTr("%1 s").arg(SessionEngine.focusDuration)
            font.pixelSize: Theme.fontSizeHuge
            color: Theme.highlightColor
            opacity: 0.0

            Timer {
                id: hintTimer
                interval: focusPage.hintHoldMs
                onTriggered: durationHint.opacity = 0.0
            }

            Behavior on opacity { NumberAnimation { duration: focusPage.hintFadeMs; easing.type: Easing.InOutQuad } }
        }
    }

    // --- Bottom half: task input during prelude, task list during focus/winddown.
    Item {
        id: taskArea
        anchors { top: arcArea.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

        // Prelude view: existing tasks shown read-only, remaining slots editable.
        Column {
            id: taskInputArea
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            visible: SessionEngine.phase === "prelude"

            Repeater {
                model: SessionEngine.tasks
                delegate: TextField {
                    text: modelData.title
                    width: parent.width
                    readOnly: true
                    color: Theme.secondaryColor
                }
            }

            // Editable slots = maxTasks - already-known tasks. Writes to
            // _taskTexts; harvested into the engine when prelude ends.
            // `index` here is the per-delegate index provided by Repeater.
            Repeater {
                model: SessionEngine.maxTasks - SessionEngine.tasks.length
                TextField {
                    placeholderText: qsTr("Task %1").arg(SessionEngine.tasks.length + index + 1)
                    width: parent.width
                    EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    EnterKey.onClicked: focus = false

                    onTextChanged: {
                        focusPage._taskTexts[index] = text
                    }
                }
            }
        }

        // Focus/winddown view: interactive task list with completion switches + +5 min extension.
        Column {
            id: taskListArea
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            visible: SessionEngine.phase !== "prelude"

            Repeater {
                model: SessionEngine.tasks

                delegate: TextSwitch {
                    width: taskListArea.width
                    text: modelData.title
                    checked: modelData.completed
                    onClicked: SessionEngine.toggleTask(index)
                }
            }

            // +5 min extension is offered once per session, in a 15 s window
            // that opens 1.5 min before the session would otherwise end
            // (remainingTotal between 76 and 90 s inclusive). Outside that
            // window the button stays hidden — a 1 s "extension" would be
            // dishonest, and an every-winddown offer was too noisy. With
            // hour-aligned 25/5 and 50/10 sessions this window lands in the
            // final break, so the same button is mirrored in BreakView.
            Button {
                text: qsTr("+5 min")
                visible: !SessionEngine.extensionUsed
                         && SessionEngine.remainingTotal > 75
                         && SessionEngine.remainingTotal <= 90
                opacity: 0.6
                anchors.horizontalCenter: parent.horizontalCenter

                onClicked: SessionEngine.requestExtension()
            }
        }
    }
}
