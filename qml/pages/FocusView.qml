import QtQuick 2.6
import Sailfish.Silica 1.0
import engine 1.0

// Focus page: arc timer on top, task list at the bottom.
// Covers three engine phases: prelude (fade-in + task entry), focus, and winddown.
// Navigation off this page is signal-driven via Connections below, not polled.
Page {
    id: focusPage

    property var _taskTexts: ["", "", ""] // buffers for up-to-3 editable prelude fields

    // --- React to engine phase changes: flash the duration hint on entering
    // focus, harvest typed-but-unsubmitted tasks when prelude ends, and leave
    // the page when the engine moves into break or end.
    Connections {
        target: SessionEngine

        onPhaseChanged: {
            if (SessionEngine.phase === "focus") {
                durationHint.opacity = 1.0
                hintTimer.restart()

                // Prelude just ended: push whatever the user typed in empty
                // slots into the engine's task list.
                var slots = 3 - SessionEngine.tasks.length
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

        // Arc-progress canvas. Colour + sweep angle depend on the phase:
        //   prelude/winddown -> orange, fixed 120° sweep scaled by remaining fade time
        //   focus            -> blue,   sweep scaled by duration (360° for 60 min)
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
                    raw = SessionEngine.preludeRemaining / 30
                else if (SessionEngine.phase === "winddown")
                    raw = SessionEngine.winddownRemaining / 10
                else if (SessionEngine.focusDuration > 0)
                    raw = SessionEngine.remainingPhase / SessionEngine.focusDuration
                else
                    raw = 0
                return Math.max(0, Math.min(1, raw))
            }
            property real startAngle: (SessionEngine.phase === "prelude" || SessionEngine.phase === "winddown")
                ? 120
                : SessionEngine.focusDuration / 10

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var cx = width / 2;
                var cy = height / 2;
                var lw = width / 20;
                var r = width / 2 - lw;

                // Background ring.
                ctx.beginPath();
                ctx.lineWidth = lw;
                ctx.strokeStyle = "#333333";
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.stroke();

                // Foreground progress arc, starting at 12 o'clock.
                var endAngle = startAngle * progress;

                ctx.beginPath();
                ctx.lineWidth = lw;
                ctx.strokeStyle = (SessionEngine.phase === "prelude" || SessionEngine.phase === "winddown") ? "#ffaa00" : "#00aaff";

                ctx.arc(
                    cx, cy, r,
                    -Math.PI / 2,
                    -Math.PI / 2 + (endAngle * Math.PI / 180),
                    false
                );
                ctx.stroke();
            }

            // 1 Hz repaint keeps the arc smooth enough for a minute-scale timer.
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: arcCanvas.requestPaint()
            }
        }

        // --- Duration hint centred in the arc: "25 min" on entering focus, fades out after 15s.
        Label {
            id: durationHint
            anchors.centerIn: arcCanvas
            text: SessionEngine.focusDuration >= 60
                  ? qsTr("%1 min").arg(Math.round(SessionEngine.focusDuration / 60))
                  : qsTr("%1 s").arg(SessionEngine.focusDuration)
            font.pixelSize: Theme.fontSizeHuge
            color: Theme.highlightColor
            opacity: 0.0

            Timer {
                id: hintTimer
                interval: 15000
                onTriggered: durationHint.opacity = 0.0
            }

            Behavior on opacity { NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad } }
        }
    }

    // --- Bottom half: task input during prelude, task list during focus/winddown.
    Item {
        id: taskArea
        anchors { top: arcArea.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

        // Prelude view: existing tasks read-only, remaining slots editable.
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

            // Editable slots = 3 - already-known tasks. Writes to _taskTexts, collected on phase change.
            Repeater {
                model: 3 - SessionEngine.tasks.length
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

            // +5 min extension is offered only during winddown and only once per session.
            Button {
                text: qsTr("+5 min")
                visible: SessionEngine.phase === "winddown" && !SessionEngine.extensionUsed
                opacity: 0.6
                anchors.horizontalCenter: parent.horizontalCenter

                onClicked: SessionEngine.requestExtension()
            }
        }
    }
}
