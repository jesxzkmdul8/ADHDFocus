import QtQuick 2.6
import Sailfish.Silica 1.0
import Qt.labs.settings 1.0
import engine 1.0

// ReentryView
// ===========
// Recap / end-of-session page. Splits the session's tasks into "Done" and
// "Open", persists the Open list to disk so SetupView can offer it as the
// next session's carry-over, and offers a "New session" button.
Page {
    id: endPage

    // --- Visual constants. Two palettes: green for done, muted orange for
    // open / carry-over. The orange tones match SetupView.colorHeading /
    // colorBullet on purpose — same semantic ("things still to do").
    readonly property color colorDoneHeading: "#66cc88"   // green section header
    readonly property color colorDoneText: "#88aa88"      // muted green tick text
    readonly property color colorOpenHeading: "#cc8866"   // muted orange section header
    readonly property color colorOpenText: "#aa8877"      // dim text for open bullets

    property var completedTasks: []
    property var openTasks: []

    // Shared storage: same Settings key as SetupView, so carry-over round-trips.
    Settings {
        id: storage
        property string carryOverTasks: "[]"
    }

    // Partition tasks on page creation; persist the open set for next launch.
    // Reassign arrays (not push) so QML bindings on completedTasks/openTasks fire.
    Component.onCompleted: {
        var tasks = SessionEngine.tasks
        var comp = []
        var open = []
        for (var i = 0; i < tasks.length; i++) {
            if (tasks[i].completed)
                comp.push(tasks[i])
            else
                open.push(tasks[i])
        }
        completedTasks = comp
        openTasks = open

        storage.carryOverTasks = JSON.stringify(open)
    }

    // Scrollable recap in case the task list ever exceeds screen height.
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge * 2

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.horizontalPageMargin }
            spacing: Theme.paddingLarge

            // --- Heading.
            Label {
                text: qsTr("Session complete")
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // --- Done section: tasks the user ticked off this session.
            Column {
                spacing: Theme.paddingSmall
                visible: completedTasks.length > 0

                Label {
                    text: qsTr("Done")
                    color: endPage.colorDoneHeading
                    font.pixelSize: Theme.fontSizeLarge
                }

                Repeater {
                    model: completedTasks

                    delegate: Label {
                        text: "\u2713  " + modelData.title
                        color: endPage.colorDoneText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }
            }

            // --- Open section: tasks that will carry over to the next session.
            Column {
                spacing: Theme.paddingSmall
                visible: openTasks.length > 0

                Label {
                    text: qsTr("Open")
                    color: endPage.colorOpenHeading
                    font.pixelSize: Theme.fontSizeLarge
                }

                Repeater {
                    model: openTasks

                    delegate: Label {
                        text: "\u2022  " + modelData.title
                        color: endPage.colorOpenText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }
            }

            // --- New session: reset the engine and go back to setup.
            Button {
                text: qsTr("New session")
                preferredWidth: Theme.buttonWidthLarge
                anchors.horizontalCenter: parent.horizontalCenter

                onClicked: {
                    SessionEngine.reset()
                    pageStack.replace(Qt.resolvedUrl("SetupView.qml"))
                }
            }
        }
    }
}
