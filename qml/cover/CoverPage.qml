import QtQuick 2.6
import Sailfish.Silica 1.0
import engine 1.0

// Home-screen cover. Shows remaining minutes while a session runs, app name otherwise.
CoverBackground {
    Label {
        id: phaseLabel
        anchors.centerIn: parent
        text: SessionEngine.isRunning ? qsTr("%1 min").arg(Math.ceil(SessionEngine.remainingTotal / 60)) : "ADHDFocus"
        font.pixelSize: Theme.fontSizeLarge
    }
}
