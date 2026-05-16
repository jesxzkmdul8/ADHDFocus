import QtQuick 2.6
import Sailfish.Silica 1.0
import engine 1.0

// Home-screen cover. Shows remaining minutes while a session runs, app name otherwise.
//
// remainingTotal is the focus+break budget and hits 0 at the start of the
// final winddown — the session keeps running for another 10 s after that,
// during which Math.ceil(0/60) would read "0 min". Show "<1 min" whenever
// the budget is below a minute (including 0) so the cover never claims the
// session is finished while it's still winding down.
CoverBackground {
    Label {
        id: phaseLabel
        anchors.centerIn: parent
        text: !SessionEngine.isRunning
              ? "ADHDFocus"
              : SessionEngine.remainingTotal < 60
                ? qsTr("<1 min")
                : qsTr("%1 min").arg(Math.ceil(SessionEngine.remainingTotal / 60))
        font.pixelSize: Theme.fontSizeLarge
    }
}
