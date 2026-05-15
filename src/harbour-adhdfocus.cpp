// harbour-adhdfocus entry point.
//
// Responsibilities:
//   1. Construct the Qt application and Sailfish view via SailfishApp helpers.
//   2. Anchor the Qt application identity (organization + application name)
//      to "harbour-adhdfocus" so Qt.labs.settings writes to the
//      sandbox-allowed config path and matches the [X-Sailjail] identity in
//      the .desktop file.
//   3. Load translations matching the system locale, with a language-only
//      fallback (de_DE -> de) and a final fall-through to the English source
//      strings if neither .qm file is present.
//   4. Add qml/ to the QML import path so `import engine 1.0` resolves to
//      qml/engine/qmldir at runtime.
//   5. Expose a `dataDir` context property carrying a normalised file:// URL
//      to /usr/share/harbour-adhdfocus/, so QML can build URLs for bundled
//      assets (sounds) without hard-coding install paths.
#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QtQml>
#include <QTranslator>
#include <QLocale>

#include "BrownNoiseGenerator.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    // Anchor the Qt application identity to harbour-adhdfocus so Qt.labs.settings
    // writes to the sandbox-allowed config path and matches the Sailjail
    // identity declared in harbour-adhdfocus.desktop.
    app->setOrganizationName(QStringLiteral("harbour-adhdfocus"));
    app->setApplicationName(QStringLiteral("harbour-adhdfocus"));

    QScopedPointer<QQuickView> view(SailfishApp::createView());

    // Try harbour-adhdfocus-<locale>.qm first (e.g. de_DE), then fall back to
    // language-only (de). If neither exists, strings remain as the English
    // source from qsTr().
    QTranslator *translator = new QTranslator(app.data());
    QString locale = QLocale::system().name();
    QString tsDir = SailfishApp::pathTo("translations").toLocalFile();
    if (translator->load("harbour-adhdfocus-" + locale, tsDir) ||
        translator->load("harbour-adhdfocus-" + locale.left(2), tsDir)) {
        app->installTranslator(translator);
    }

    // Needed for `import engine 1.0` to resolve qml/engine/qmldir at runtime.
    view->engine()->addImportPath(SailfishApp::pathTo("qml").toString());

    // QML registration for the synthesized brown-noise bed. Lets QML write
    // `import BrownNoise 1.0; BrownNoiseGenerator { ... }` and removes the
    // need to ship a recorded audio file for the focus bed.
    qmlRegisterType<BrownNoiseGenerator>("BrownNoise", 1, 0, "BrownNoiseGenerator");

    // Expose the install data directory (e.g. /usr/share/harbour-adhdfocus) so
    // QML can build absolute file:// URLs for bundled assets like the audio
    // files. Using SailfishApp::pathTo means QML stays correct under any
    // install prefix or future rename. The trailing slash is enforced here so
    // QML can safely concatenate `dataDir + "sounds/..."`; the SailfishApp API
    // currently returns one but does not contractually guarantee it.
    QString dataDir = SailfishApp::pathTo(QString()).toString();
    if (!dataDir.endsWith(QLatin1Char('/'))) {
        dataDir.append(QLatin1Char('/'));
    }
    view->rootContext()->setContextProperty(QStringLiteral("dataDir"), dataDir);

    view->setSource(SailfishApp::pathToMainQml());
    view->showFullScreen();
    return app->exec();
}
