#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QResource>
#include <QTimer>
#include <QVariant>

#include <algorithm>
#include <cstdio>
#include <memory>
#include <random>
#include <string>
#include <vector>
#include <utility>

namespace {
constexpr const char *kMountRoot = "/mods/gem_cascade";
constexpr const char *kEntryUrl = "qrc:/mods/gem_cascade/Main.qml";
QStringList gDiagnostics;
QtMessageHandler gPreviousHandler = nullptr;

bool diagnosticIsFatal(const QString &message)
{
    const QString lower = message.toLower();
    const bool qmlRelevant = lower.contains("gem_cascade") || lower.contains("qrc:/mods/gem_cascade") ||
                             lower.contains("qrc:/mods/gem_cascade");
    if (!qmlRelevant)
        return false;
    static const QStringList fatalPatterns = {
        "referenceerror", "typeerror", "unable to assign", "cannot assign",
        "invalid write to global property", "cannot read property", "expected token",
        "is not defined", "cannot open:", "no such file", "binding loop",
        "recursive rearrange", "incorrect argument", "qfont::setpixelsize",
        "cannot anchor", "anchors on an item that is managed by a layout",
        "non-existent property", "invalid property assignment", "is not a type",
        "type unavailable", "module \"", "is not installed", "failed to load component"
    };
    return std::any_of(fatalPatterns.cbegin(), fatalPatterns.cend(),
                       [&](const QString &pattern) { return lower.contains(pattern); });
}

void messageHandler(QtMsgType type, const QMessageLogContext &ctx, const QString &message)
{
    if (diagnosticIsFatal(message))
        gDiagnostics.push_back(message);
    if (gPreviousHandler)
        gPreviousHandler(type, ctx, message);
}

class ThemeStub final : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE QVariant color(const QString &token) const
    {
        const QVariantMap colors {
            {"color.background", "#10141c"}, {"color.surfaceRaised", "#1b2230"},
            {"color.surfaceInteractive", "#252e3e"}, {"color.border", "#3b465a"},
            {"color.text", "#f2f5f8"}, {"color.textMuted", "#9ba8ba"},
            {"color.primary", "#6c8cff"}, {"color.primaryHover", "#88a2ff"},
            {"color.accent", "#9d7cff"}, {"color.info", "#58a6ff"}
        };
        return colors.value(token, "#f2f5f8");
    }
    Q_INVOKABLE double number(const QString &token) const
    {
        const QVariantMap numbers {
            {"alias.page.padding", 16.0}, {"alias.page.gap", 10.0}, {"alias.gameTile.gap", 4.0},
            {"alias.card.padding", 12.0}, {"alias.card.gap", 8.0}, {"alias.card.radius", 12.0},
            {"alias.card.borderWidth", 1.0}, {"alias.button.gap", 8.0}, {"alias.button.height", 44.0},
            {"alias.button.touchTarget", 44.0}, {"alias.button.paddingX", 14.0},
            {"alias.button.hoverScale", 1.02}, {"alias.button.pressedScale", 0.98},
            {"metric.control.lg", 96.0}, {"metric.control.sm", 36.0}, {"metric.control.xs", 28.0},
            {"metric.icon.md", 24.0}, {"metric.space.xs", 8.0}, {"metric.space.xxxs", 2.0},
            {"metric.font.xs", 12.0}, {"metric.font.sm", 14.0}, {"metric.font.md", 16.0}, {"metric.font.lg", 22.0}
        };
        return numbers.value(token, 8.0).toDouble();
    }
    Q_INVOKABLE QVariantMap surface(const QString &) const
    {
        return {{"color", "#1b2230"}, {"radius", 12.0}, {"borderWidth", 1.0}, {"border", "#3b465a"}};
    }
signals:
    void themeChanged();
    void changed();
};

class SettingsStub final : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE QVariant value(const QString &, const QVariant &fallback = {}) const { return fallback; }
};

class I18nStub final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString gameId READ gameId NOTIFY gameIdChanged)
public:
    using QObject::QObject;
    bool ready() const { return true; }
    QString gameId() const { return QStringLiteral("gem_cascade"); }
    Q_INVOKABLE QString text(const QString &, const QString &fallback = {}) const { return fallback; }
signals:
    void readyChanged();
    void localeChanged();
    void languageChanged();
    void translationsChanged();
    void gameIdChanged();
};

class SaveStub final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString gameId READ gameId NOTIFY gameIdChanged)
public:
    using QObject::QObject;
    bool ready() const { return true; }
    QString gameId() const { return QStringLiteral("gem_cascade"); }
    Q_INVOKABLE bool load(const QString &) { return false; }
    Q_INVOKABLE bool save(const QString &) { return true; }
    Q_INVOKABLE QVariant get(const QString &, const QVariant &fallback = {}) const { return fallback; }
    Q_INVOKABLE void set(const QString &, const QVariant &) {}
signals:
    void readyChanged();
    void gameIdChanged();
};

class RandomStub final : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void seed(const QVariant &) { mState = 0x6D2B79F5u; }
    Q_INVOKABLE int nextInt(int lo, int hi)
    {
        if (hi < lo)
            std::swap(lo, hi);
        mState = mState * 1664525u + 1013904223u;
        const quint32 span = quint32(hi - lo + 1);
        return lo + int(mState % std::max<quint32>(1u, span));
    }
private:
    quint32 mState = 0x6D2B79F5u;
};

class HapticsStub final : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void light() {}
    Q_INVOKABLE void medium() {}
    Q_INVOKABLE void heavy() {}
};

class StatsStub final : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void submitHighScore(qint64) {}
    Q_INVOKABLE void submitHighScore(qint64, const QString &) {}
    Q_INVOKABLE void increment(const QString &) {}
};

class AchievementsStub final : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void unlock(const QString &) {}
};

class LifecycleStub final : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
signals:
    void saveRequested();
    void backgrounded();
    void paused();
    void closing();
    void unloading();
};

class InputStub final : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
signals:
    void actionPressed(const QString &action, const QVariant &value);
};

void pumpEvents(int milliseconds)
{
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < milliseconds) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
    }
}

bool verifyFile(const QString &path)
{
    if (!QFileInfo::exists(path)) {
        std::fprintf(stderr, "[FAIL] Mounted RCC file missing: %s\n", qPrintable(path));
        return false;
    }
    std::printf("[OK] %s\n", qPrintable(path));
    return true;
}

QObject *createComponent(QQmlEngine &engine, int width, int height)
{
    QQmlComponent component(&engine, QUrl(QString::fromLatin1(kEntryUrl)));
    if (component.status() == QQmlComponent::Loading)
        pumpEvents(100);
    if (component.isError()) {
        for (const auto &error : component.errors())
            std::fprintf(stderr, "[FAIL] QML component: %s\n", qPrintable(error.toString()));
        return nullptr;
    }
    QObject *object = component.beginCreate(engine.rootContext());
    if (!object) {
        for (const auto &error : component.errors())
            std::fprintf(stderr, "[FAIL] QML beginCreate: %s\n", qPrintable(error.toString()));
        return nullptr;
    }
    object->setProperty("width", width);
    object->setProperty("height", height);
    component.completeCreate();
    if (component.isError()) {
        for (const auto &error : component.errors())
            std::fprintf(stderr, "[FAIL] QML completeCreate: %s\n", qPrintable(error.toString()));
        delete object;
        return nullptr;
    }
    return object;
}

bool runNoServiceFallbackSmoke()
{
    gDiagnostics.clear();
    QQmlEngine engine;
    std::unique_ptr<QObject> root(createComponent(engine, 360, 640));
    if (!root)
        return false;
    pumpEvents(180);
    if (!gDiagnostics.isEmpty()) {
        for (const QString &line : std::as_const(gDiagnostics))
            std::fprintf(stderr, "[FAIL] No-service QML diagnostic: %s\n", qPrintable(line));
        return false;
    }
    std::printf("[OK] QML fallback instantiation without injected host services\n");
    return true;
}

bool runHostStubSmoke()
{
    gDiagnostics.clear();
    ThemeStub theme;
    SettingsStub settings;
    I18nStub i18n;
    SaveStub save;
    RandomStub random;
    HapticsStub haptics;
    StatsStub stats;
    AchievementsStub achievements;
    LifecycleStub lifecycle;
    InputStub input;

    QQmlEngine engine;
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty("GameTheme", &theme);
    ctx->setContextProperty("GameSettings", &settings);
    ctx->setContextProperty("GameI18n", &i18n);
    ctx->setContextProperty("GameSave", &save);
    ctx->setContextProperty("GameRandom", &random);
    ctx->setContextProperty("Haptics", &haptics);
    ctx->setContextProperty("GameStats", &stats);
    ctx->setContextProperty("Achievements", &achievements);
    ctx->setContextProperty("Lifecycle", &lifecycle);
    ctx->setContextProperty("GameInput", &input);

    std::unique_ptr<QObject> root(createComponent(engine, 960, 720));
    if (!root)
        return false;
    pumpEvents(950);

    if (!root->property("initialized").toBool()) {
        std::fprintf(stderr, "[FAIL] Gem Cascade did not initialize with ready host stubs.\n");
        return false;
    }
    const QVariant board = root->property("board");
    if (!board.isValid()) {
        std::fprintf(stderr, "[FAIL] Gem Cascade board property is invalid after initialization.\n");
        return false;
    }

    emit theme.themeChanged();
    emit i18n.translationsChanged();
    emit lifecycle.backgrounded();
    pumpEvents(120);

    if (!gDiagnostics.isEmpty()) {
        for (const QString &line : std::as_const(gDiagnostics))
            std::fprintf(stderr, "[FAIL] Host-stub QML diagnostic: %s\n", qPrintable(line));
        return false;
    }
    std::printf("[OK] QQmlEngine host-stub instantiation/lifecycle/theme/i18n smoke\n");
    return true;
}
} // namespace

int main(int argc, char **argv)
{
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", QByteArrayLiteral("offscreen"));
    QGuiApplication app(argc, argv);
    if (argc != 2) {
        std::fprintf(stderr, "Usage: gem_cascade_rcc_smoke <gem_cascade-x.y.z.rcc>\n");
        return 2;
    }

    const QString rccPath = QFileInfo(QString::fromLocal8Bit(argv[1])).absoluteFilePath();
    if (!QFileInfo::exists(rccPath)) {
        std::fprintf(stderr, "[FAIL] RCC does not exist: %s\n", qPrintable(rccPath));
        return 2;
    }

    if (!QResource::registerResource(rccPath, QString::fromLatin1(kMountRoot))) {
        std::fprintf(stderr, "[FAIL] QResource::registerResource failed for %s\n", qPrintable(rccPath));
        return 3;
    }

    bool ok = true;
    const QStringList required {
        ":/mods/gem_cascade/Main.qml", ":/mods/gem_cascade/manifest.json",
        ":/mods/gem_cascade/js/BoardLogic.js", ":/mods/gem_cascade/js/LevelLogic.js",
        ":/mods/gem_cascade/components/GemCell.qml", ":/mods/gem_cascade/components/TutorialOverlay.qml",
        ":/mods/gem_cascade/assets/icon.png",
        ":/mods/gem_cascade/assets/gems/ruby.svg", ":/mods/gem_cascade/assets/gems/sapphire.svg",
        ":/mods/gem_cascade/assets/gems/emerald.svg", ":/mods/gem_cascade/assets/gems/sunstone.svg",
        ":/mods/gem_cascade/assets/gems/amethyst.svg", ":/mods/gem_cascade/assets/gems/pearl.svg",
        ":/mods/gem_cascade/i18n/en.json", ":/mods/gem_cascade/i18n/tr.json",
        ":/mods/gem_cascade/i18n/az.json", ":/mods/gem_cascade/i18n/ru.json",
        ":/mods/gem_cascade/i18n/de.json", ":/mods/gem_cascade/i18n/fr.json",
        ":/mods/gem_cascade/i18n/es.json", ":/mods/gem_cascade/i18n/pt.json",
        ":/mods/gem_cascade/i18n/zh.json", ":/mods/gem_cascade/i18n/ja.json"
    };
    for (const QString &path : required)
        ok = verifyFile(path) && ok;

    const QString doubled = ":/mods/gem_cascade/mods/gem_cascade/Main.qml";
    if (QFileInfo::exists(doubled)) {
        std::fprintf(stderr, "[FAIL] Doubled host prefix exists: %s\n", qPrintable(doubled));
        ok = false;
    } else {
        std::printf("[OK] Doubled host prefix is absent\n");
    }

    QFile manifestFile(QStringLiteral(":/mods/gem_cascade/manifest.json"));
    if (!manifestFile.open(QIODevice::ReadOnly)) {
        std::fprintf(stderr, "[FAIL] Mounted manifest cannot be opened.\n");
        ok = false;
    } else {
        QJsonParseError parseError{};
        const QJsonDocument doc = QJsonDocument::fromJson(manifestFile.readAll(), &parseError);
        const QJsonObject obj = doc.object();
        if (parseError.error != QJsonParseError::NoError || obj.value("id").toString() != QStringLiteral("gem_cascade") ||
            obj.value("entry").toString() != QStringLiteral("Main.qml") || obj.value("version").toString() != QStringLiteral("6.7.0")) {
            std::fprintf(stderr, "[FAIL] Mounted manifest id/entry/version contract invalid.\n");
            ok = false;
        }
        const QString iconPath = obj.value("icon_path").toString();
        if (iconPath.isEmpty() || !QFileInfo::exists(QStringLiteral(":/mods/gem_cascade/") + iconPath)) {
            std::fprintf(stderr, "[FAIL] Mounted manifest icon_path is missing.\n");
            ok = false;
        } else {
            std::printf("[OK] Mounted manifest id/entry/version/icon contract\n");
        }
    }

    gPreviousHandler = qInstallMessageHandler(messageHandler);
    ok = runNoServiceFallbackSmoke() && ok;
    ok = runHostStubSmoke() && ok;
    qInstallMessageHandler(gPreviousHandler);

    QResource::unregisterResource(rccPath, QString::fromLatin1(kMountRoot));
    if (!ok) {
        std::fprintf(stderr, "[FAIL] Gem Cascade RCC post-build smoke failed.\n");
        return 4;
    }
    std::printf("[PASS] Gem Cascade RCC mount + QQmlEngine post-build smoke\n");
    return 0;
}

#include "rcc_smoke.moc"
