TARGET = ADHDFocus
CONFIG += sailfishapp
QT += multimedia

SOURCES += src/ADHDFocus.cpp

DISTFILES += \
    qml/ADHDFocus.qml \
    qml/engine/SessionEngine.qml \
    qml/engine/qmldir \
    qml/cover/CoverPage.qml \
    qml/pages/SetupView.qml \
    qml/pages/FocusView.qml \
    qml/pages/BreakView.qml \
    qml/pages/ReentryView.qml \
    rpm/ADHDFocus.spec \
    ADHDFocus.desktop \
    translations/ADHDFocus.ts \
    translations/ADHDFocus-de.ts

CONFIG += sailfishapp_i18n
TRANSLATIONS += translations/ADHDFocus.ts translations/ADHDFocus-de.ts

sounds.files = assets/sounds/brown_noise.ogg \
               assets/sounds/ping_start.wav \
               assets/sounds/ping_end.wav
sounds.path = /usr/share/$${TARGET}/sounds

icon86.files = icons/86x86/ADHDFocus.png
icon86.path = /usr/share/icons/hicolor/86x86/apps
icon108.files = icons/108x108/ADHDFocus.png
icon108.path = /usr/share/icons/hicolor/108x108/apps
icon128.files = icons/128x128/ADHDFocus.png
icon128.path = /usr/share/icons/hicolor/128x128/apps
icon172.files = icons/172x172/ADHDFocus.png
icon172.path = /usr/share/icons/hicolor/172x172/apps

INSTALLS += icon86 icon108 icon128 icon172 sounds
