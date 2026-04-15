import QtQuick 2.6
import Sailfish.Silica 1.0
import engine 1.0

// Break page: green arc on top, passive task list below (completed ones fade out).
Page {
    id: breakPage

    // --- Phase-driven navigation: return to focus when break ends, or end screen if done.
    Timer {
        interval: 500
        running: true
        repeat: true

        onTriggered: {
            if (SessionEngine.phase === "prelude" || SessionEngine.phase === "focus")
                pageStack.replace(Qt.resolvedUrl("FocusView.qml"))

            if (SessionEngine.phase === "end")
                pageStack.replace(Qt.resolvedUrl("ReentryView.qml"))
        }
    }

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

            property real progress: SessionEngine.remainingPhase / SessionEngine.breakDuration

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

                // Green progress arc (same angular scale as focus: seconds/10 degrees).
                var startAngle = SessionEngine.breakDuration / 10;
                var endAngle = (startAngle * progress) * (Math.PI / 180);

                ctx.beginPath();
                ctx.lineWidth = lw;
                ctx.strokeStyle = "#66cc88";

                ctx.arc(
                    cx, cy, r,
                    -Math.PI / 2,
                    -Math.PI / 2 + endAngle,
                    false
                );
                ctx.stroke();
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: breakArc.requestPaint()
            }
        }

        // --- Duration hint ("5 min break") centred in the arc; fades out after 15s.
        Label {
            id: breakHint
            anchors.centerIn: breakArc
            text: SessionEngine.breakDuration >= 60
                   ? qsTr("%1 min break").arg(Math.round(SessionEngine.breakDuration / 60))
                   : qsTr("%1 s break").arg(SessionEngine.breakDuration)
            font.pixelSize: Theme.fontSizeHuge
            color: "#66cc88"

            Timer {
                id: breakHintTimer
                interval: 15000
                running: true
                onTriggered: breakHint.opacity = 0.0
            }

            Behavior on opacity { NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad } }
        }
    }

    // --- Bottom half: task recap. Tasks are read-only; completed ones fade out visually.
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

                    // Fade completed tasks out over 1.5s once they render.
                    Component.onCompleted: {
                        if (modelData.completed)
                            fadeOut.start()
                    }

                    NumberAnimation on opacity {
                        id: fadeOut
                        running: false
                        from: 1; to: 0
                        duration: 1500
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
