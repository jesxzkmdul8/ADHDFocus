import QtQuick 2.6
import Sailfish.Silica 1.0
import engine 1.0

// Focus page: arc timer on top, task list at the bottom.
// Covers three engine phases: prelude (fade-in + task entry), focus, and winddown.
Page {
    id: focusPage

    property string _prevPhase: ""
    property var _taskTexts: ["", "", ""] // buffers for up-to-3 editable prelude fields

    // --- Phase-driven page navigation and duration-hint trigger.
    // Polls twice a second; leaves for BreakView/ReentryView when engine says so.
    Timer {
        interval: 500
        running: true
        repeat: true

        onTriggered: {
            // On entering 'focus', flash the "25 min" / "50 min" hint for 15s.
            if (SessionEngine.phase === "focus" && focusPage._prevPhase !== "focus") {
                durationHint.opacity = 1.0
                hintTimer.restart()
            }
            focusPage._prevPhase = SessionEngine.phase

            if (SessionEngine.phase === "break")
                pageStack.replace(Qt.resolvedUrl("BreakView.qml"))

            if (SessionEngine.phase === "end")
                pageStack.replace(Qt.resolvedUrl("ReentryView.qml"))
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

            property real progress: SessionEngine.phase === "prelude"
                ? SessionEngine.preludeRemaining / 30
                : SessionEngine.phase === "winddown"
                  ? SessionEngine.winddownRemaining / 10
                  : SessionEngine.remainingPhase / SessionEngine.focusDuration
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

    // Kick off the deferred collector when the page becomes active in prelude.
    onStatusChanged: {
        if (status === PageStatus.Active && SessionEngine.phase === "prelude")
            _collectTimer.start()
    }

    // Waits until prelude ends, then pushes whatever the user typed in empty slots
    // into SessionEngine.tasks. Single-shot per prelude.
    Timer {
        id: _collectTimer
        interval: 500
        running: false
        repeat: true

        onTriggered: {
            if (SessionEngine.phase !== "prelude") {
                var slots = 3 - SessionEngine.tasks.length
                for (var i = 0; i < slots; i++) {
                    var t = focusPage._taskTexts[i].trim()
                    if (t.length > 0)
                        SessionEngine.addTask(t)
                }
                focusPage._taskTexts = ["", "", ""]
                stop()
            }
        }
    }
}
