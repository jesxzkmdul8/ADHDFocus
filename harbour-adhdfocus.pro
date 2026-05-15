TARGET = harbour-adhdfocus
CONFIG += sailfishapp
QT += multimedia

SOURCES += src/harbour-adhdfocus.cpp \
           src/BrownNoiseGenerator.cpp

HEADERS += src/BrownNoiseGenerator.h

DISTFILES += \
    qml/harbour-adhdfocus.qml \
    qml/engine/SessionEngine.qml \
    qml/engine/qmldir \
    qml/cover/CoverPage.qml \
    qml/pages/SetupView.qml \
    qml/pages/FocusView.qml \
    qml/pages/BreakView.qml \
    qml/pages/ReentryView.qml \
    rpm/harbour-adhdfocus.spec \
    harbour-adhdfocus.desktop \
    translations/harbour-adhdfocus.ts \
    translations/harbour-adhdfocus-de.ts

CONFIG += sailfishapp_i18n
TRANSLATIONS += translations/harbour-adhdfocus.ts translations/harbour-adhdfocus-de.ts

sounds.files = assets/sounds/ping_start.wav \
               assets/sounds/ping_end.wav
sounds.path = /usr/share/$${TARGET}/sounds

icon86.files = icons/86x86/harbour-adhdfocus.png
icon86.path = /usr/share/icons/hicolor/86x86/apps
icon108.files = icons/108x108/harbour-adhdfocus.png
icon108.path = /usr/share/icons/hicolor/108x108/apps
icon128.files = icons/128x128/harbour-adhdfocus.png
icon128.path = /usr/share/icons/hicolor/128x128/apps
icon172.files = icons/172x172/harbour-adhdfocus.png
icon172.path = /usr/share/icons/hicolor/172x172/apps

INSTALLS += icon86 icon108 icon128 icon172 sounds
