// harbour-adhdfocus entry point. Wires up the SailfishApp view, installs a
// translator based on the system locale, exposes the qml/ tree as an import
// path so the engine singleton (module "engine") can be resolved, and exposes
// a `dataDir` context property for QML to locate bundled sounds without
// hard-coding /usr/share/<name>/ paths.
#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QTranslator>
#include <QLocale>

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
