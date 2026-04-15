// ADHDFocus entry point. Wires up the SailfishApp view, installs a translator
// based on the system locale, and exposes the qml/ tree as an import path so
// the engine singleton (module "engine") can be resolved.
#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlEngine>
#include <QTranslator>
#include <QLocale>

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    QScopedPointer<QQuickView> view(SailfishApp::createView());

    // Try ADHDFocus-<locale>.qm first (e.g. de_DE), then fall back to language-only (de).
    // If neither exists, strings remain as the English source from qsTr().
    QTranslator *translator = new QTranslator(app.data());
    QString locale = QLocale::system().name();
    QString tsDir = SailfishApp::pathTo("translations").toLocalFile();
    if (translator->load("ADHDFocus-" + locale, tsDir) ||
        translator->load("ADHDFocus-" + locale.left(2), tsDir)) {
        app->installTranslator(translator);
    }

    // Needed for `import engine 1.0` to resolve qml/engine/qmldir at runtime.
    view->engine()->addImportPath(SailfishApp::pathTo("qml").toString());

    view->setSource(SailfishApp::pathToMainQml());
    view->showFullScreen();
    return app->exec();
}
