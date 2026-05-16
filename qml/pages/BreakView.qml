import QtQuick 2.6
import Sailfish.Silica 1.0
import engine 1.0

// BreakView
// =========
// The page shown during a break interval. Green arc on top, a recap of the
// session's tasks below (read-only; completed ones fade out so the user can
// see at a glance what they ticked off).
//
// Navigation off this page is signal-driven via the Connections block
// below; once the engine moves back into "prelude" / "focus" we hand off
// to FocusView, or to ReentryView if the session ended on a break.
Page {
    id: breakPage

    // --- Visual constants.
    readonly property color colorBreak: "#66cc88"  // green: the break arc + hint
    readonly property color colorRing: "#333333"   // background ring of the arc

    readonly property int hintHoldMs: 15000
    readonly property int hintFadeMs: 1500

    // --- Engine reactions.
    //
    // `Connections` listens for the engine's `phaseChanged` signal (every
    // QML property has one auto-generated). The body runs whenever
    // SessionEngine.phase is set to a different value.
    Connections {
        target: SessionEngine

        onPhaseChanged: {
            if (SessionEngine.phase === "prelude" || SessionEngine.phase === "focus")
                pageStack.replace(Qt.resolvedUrl("FocusView.qml"))
            else if (SessionEngine.phase === "end")
                pageStack.replace(Qt.resolvedUrl("ReentryView.qml"))
        }
    }

    // Trigger the hint flash + auto-fade on page creation. FocusView does
    // the equivalent from Connections.onPhaseChanged because it stays
    // mounted across phases; BreakView is recreated via pageStack.replace
    // every time the engine enters break, so onCompleted runs once per
    // break entry and is the right hook here.
    Component.onCompleted: breakHintTimer.start()

    // --- Top half: green break arc (angle scaled by breakDuration).
    Item {
        id: arcArea
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.height / 2

        Canvas {
            id: breakArc
            width: Math.min(parent.width, parent.height) * 0.85
            height: width
            anchors.centerIn: parent

            // Fraction of the wedge still to draw, clamped to [0, 1].
            // Guarded against breakDuration == 0.
            property real progress: SessionEngine.breakDuration > 0
                ? Math.max(0, Math.min(1, SessionEngine.remainingPhase / SessionEngine.breakDuration))
                : 0

            onPaint: {
                // HTML5-Canvas API. Coordinates: (0,0) is the top-left;
                // we draw the arc centred at (cx, cy).
                var ctx = getContext("2d");
                ctx.reset();

                var cx = width / 2;
                var cy = height / 2;
                var lw = width / 20;     // ring thickness, ~5% of width
                var r = width / 2 - lw;  // radius, leaving room for the line

                // Background ring (full circle, dim).
                ctx.beginPath();
                ctx.lineWidth = lw;
                ctx.strokeStyle = breakPage.colorRing;
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.stroke();

                // Foreground arc. Same angular scale as the focus arc:
                // seconds / 10 = degrees (5 min -> 30°, 10 min -> 60°).
                // Canvas measures angles in radians; -π/2 starts at
                // 12 o'clock and the wedge sweeps clockwise.
                var startAngleDeg = SessionEngine.breakDuration / 10;
                var endAngleRad = (startAngleDeg * progress) * (Math.PI / 180);

                ctx.beginPath();
                ctx.lineWidth = lw;
                ctx.strokeStyle = breakPage.colorBreak;

                ctx.arc(
                    cx, cy, r,
                    -Math.PI / 2,
                    -Math.PI / 2 + endAngleRad,
                    false
                );
                ctx.stroke();
            }

            // Canvas does not auto-repaint when properties change; we poke
            // it once a second, which is plenty for a minute-scale timer.
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: breakArc.requestPaint()
            }
        }

        // --- Duration hint ("5 min break") centred in the arc; fades out
        // after hintHoldMs. Started from Component.onCompleted above so the
        // trigger is explicit (matches FocusView).
        Label {
            id: breakHint
            anchors.centerIn: breakArc
            text: SessionEngine.breakDuration >= 60
                   ? qsTr("%1 min break").arg(Math.round(SessionEngine.breakDuration / 60))
                   : qsTr("%1 s break").arg(SessionEngine.breakDuration)
            font.pixelSize: Theme.fontSizeHuge
            color: breakPage.colorBreak

            Timer {
                id: breakHintTimer
                interval: breakPage.hintHoldMs
                onTriggered: breakHint.opacity = 0.0
            }

            Behavior on opacity { NumberAnimation { duration: breakPage.hintFadeMs; easing.type: Easing.InOutQuad } }
        }
    }

    // --- Bottom half: task recap. Tasks are read-only; completed ones fade
    // out visually so the user can see at a glance what they ticked off.
    Item {
        id: taskArea
        anchors { top: arcArea.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

        Column {
            id: taskListArea
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }

            Repeater {
                model: SessionEngine.tasks

                delegate: TextSwitch {
                    width: taskListArea.width
                    text: modelData.title
                    checked: modelData.completed
                    enabled: false
                    opacity: 1

                    // Fade completed tasks out once they render. The duration
                    // matches BreakView.hintFadeMs for visual coherence.
                    Component.onCompleted: {
                        if (modelData.completed)
                            fadeOut.start()
                    }

                    NumberAnimation on opacity {
                        id: fadeOut
                        running: false
                        from: 1; to: 0
                        duration: breakPage.hintFadeMs
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            // +5 min extension is offered in a 15 s window that opens
            // 1.5 min before each break ends — i.e. when the per-phase
            // counter remainingPhase drops into (75, 90]. Same 90 s lead
            // time as the original end-of-session offer, but applied to
            // every cycle. Clicking jumps directly into focus phase;
            // BreakView's onPhaseChanged then replaces this page with
            // FocusView.
            Button {
                text: qsTr("+5 min")
                visible: SessionEngine.phase === "break"
                         && SessionEngine.remainingPhase > 75
                         && SessionEngine.remainingPhase <= 90
                opacity: 0.6
                anchors.horizontalCenter: parent.horizontalCenter

                onClicked: SessionEngine.requestExtension()
            }
        }
    }
}
