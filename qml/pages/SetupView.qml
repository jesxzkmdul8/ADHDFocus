import QtQuick 2.6
import Sailfish.Silica 1.0
import Qt.labs.settings 1.0
import engine 1.0

// SetupView
// =========
// Entry page: pick session length, pick the focus/break mode, and optionally
// resume the open tasks left over from the previous session.
//
// Naming convention: properties whose name starts with an underscore (`_`)
// are view-local state — they exist only to track UI selections that are
// committed to the engine on "Start session". Anything without the prefix
// is part of the page's public surface.
Page {
    id: setupPage

    // --- Visual constants for the carry-over block.
    readonly property color colorHeading: "#cc8866"  // muted orange section header
    readonly property color colorBullet: "#aa8877"   // dim text for bullet entries

    property var carryOver: []          // unfinished tasks from previous session
    property string _mode: "25/5"       // selected interval mode (see _availableModes)
    property bool _useCarryOver: false  // toggled by Continue / Start fresh chips
    property int _hours: 2              // selected session length in hours

    // --- Interval modes available on the picker.
    //
    // Each entry: { label: display text, value: engine mode string, testOnly?: bool }.
    // Entries flagged `testOnly` are only rendered when `_testModesEnabled`
    // is true — flip that flag (or delete the entry) to take the test mode
    // out of the UI without touching the engine. The "5/5" entry is a
    // dev/test convenience; it has a matching branch in SessionEngine.init().
    readonly property bool _testModesEnabled: true
    readonly property var _availableModes: [
        { label: "25 / 5", value: "25/5" },
        { label: "50 / 10", value: "50/10" },
        { label: "5 / 5", value: "5/5", testOnly: true }
    ]

    // Persistent store for tasks left open after the last session.
    Settings {
        id: storage
        property string carryOverTasks: "[]"
    }

    // Load carry-over on page creation; default Continue if something to resume.
    Component.onCompleted: {
        carryOver = JSON.parse(storage.carryOverTasks)
        _useCarryOver = carryOver.length > 0
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingLarge

        // --- Carry-over block: shows unfinished tasks + Continue/Start fresh toggle.
        Column {
            spacing: Theme.paddingMedium
            visible: carryOver.length > 0

            Label {
                text: qsTr("Open tasks")
                color: setupPage.colorHeading
                font.pixelSize: Theme.fontSizeLarge
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Bullet list of tasks carried over from the last session.
            Repeater {
                model: carryOver

                delegate: Label {
                    text: "\u2022  " + modelData.title
                    color: setupPage.colorBullet
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Chip-style toggle: Continue with carry-over, or Start fresh.
            Row {
                spacing: Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter

                BackgroundItem {
                    width: continueLabel.implicitWidth + Theme.paddingLarge * 2
                    height: Theme.itemSizeSmall

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall
                        color: setupPage._useCarryOver ? Theme.highlightColor : "transparent"
                        border.color: Theme.highlightColor
                        border.width: 1
                    }

                    Label {
                        id: continueLabel
                        anchors.centerIn: parent
                        text: qsTr("Continue")
                        color: setupPage._useCarryOver ? Theme.highlightDimmerColor : Theme.primaryColor
                    }

                    onClicked: setupPage._useCarryOver = true
                }

                BackgroundItem {
                    width: freshLabel.implicitWidth + Theme.paddingLarge * 2
                    height: Theme.itemSizeSmall

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall
                        color: !setupPage._useCarryOver ? Theme.highlightColor : "transparent"
                        border.color: Theme.highlightColor
                        border.width: 1
                    }

                    Label {
                        id: freshLabel
                        anchors.centerIn: parent
                        text: qsTr("Start fresh")
                        color: !setupPage._useCarryOver ? Theme.highlightDimmerColor : Theme.primaryColor
                    }

                    onClicked: setupPage._useCarryOver = false
                }
            }
        }

        // --- Total session length: chips for 1/2/3/4 hours.
        Label {
            text: qsTr("Duration")
            color: Theme.secondaryHighlightColor
            font.pixelSize: Theme.fontSizeSmall
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            spacing: Theme.paddingLarge
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: [1, 2, 3, 4]

                delegate: BackgroundItem {
                    width: Theme.itemSizeSmall
                    height: Theme.itemSizeSmall

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall
                        color: setupPage._hours === modelData ? Theme.highlightColor : "transparent"
                        border.color: Theme.highlightColor
                        border.width: 1
                    }

                    Label {
                        anchors.centerIn: parent
                        text: qsTr("%1 h").arg(modelData)
                        color: setupPage._hours === modelData ? Theme.highlightDimmerColor : Theme.primaryColor
                    }

                    onClicked: setupPage._hours = modelData
                }
            }
        }

        // --- Mode selector chips: 25/5 classic vs 50/10 deep work.
        Label {
            text: qsTr("Interval")
            color: Theme.secondaryHighlightColor
            font.pixelSize: Theme.fontSizeSmall
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            spacing: Theme.paddingLarge
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: setupPage._availableModes

                delegate: BackgroundItem {
                    visible: !modelData.testOnly || setupPage._testModesEnabled
                    width: Theme.itemSizeExtraLarge
                    height: Theme.itemSizeSmall

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall
                        color: setupPage._mode === modelData.value ? Theme.highlightColor : "transparent"
                        border.color: Theme.highlightColor
                        border.width: 1
                    }

                    Label {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: setupPage._mode === modelData.value ? Theme.highlightDimmerColor : Theme.primaryColor
                    }

                    onClicked: setupPage._mode = modelData.value
                }
            }
        }

        // --- Start button: validates input, inits engine, clears carry-over storage, navigates to focus view.
        Button {
            text: qsTr("Start session")
            preferredWidth: Theme.buttonWidthLarge
            anchors.horizontalCenter: parent.horizontalCenter

            onClicked: {
                var taskList = setupPage._useCarryOver ? carryOver : []

                SessionEngine.init(setupPage._hours * 3600, setupPage._mode, taskList)
                storage.carryOverTasks = "[]"
                SessionEngine.start()

                pageStack.replace(Qt.resolvedUrl("FocusView.qml"))
            }
        }
    }

    // Test-mode launcher kept here commented out for future re-enable:
    //
    // Button {
    //     text: qsTr("Test (1 min)")
    //     anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Theme.paddingLarge }
    //     opacity: 0.4
    //     onClicked: {
    //         SessionEngine.init(75, "25/5", [])
    //         SessionEngine.focusDuration = 30
    //         SessionEngine.breakDuration = 15
    //         storage.carryOverTasks = "[]"
    //         SessionEngine.start()
    //         pageStack.replace(Qt.resolvedUrl("FocusView.qml"))
    //     }
    // }
}
