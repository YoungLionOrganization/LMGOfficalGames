
"""Mount both Pocket Factory RCC editions in Qt Quick using fixture host services."""

import argparse
import json
import math
import os
from pathlib import Path
import time

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QObject, QResource, QUrl, qInstallMessageHandler
from PySide6.QtGui import QFont, QFontDatabase, QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent
from PySide6.QtQuick import QQuickWindow

SERVICE="import QtQuick\nQtObject {\n    property string gameId\n    property string language: \"en\"\n    property bool ready: true\n    property bool valid: true\n    property int safeWidth: 1000\n    property int safeTop: 0\n    property int safeBottom: 0\n    property string lastError: \"Fixture failure\"\n    property var values: ({})\n    property var saveValues: ({})\n    property var migrations: ({})\n    property bool stored: false\n    property bool corrupt: false\n    property int schema: 0\n    property int commits: 0\n    signal gameChanged()\n    signal changed()\n    signal saveRequested()\n    signal actionPressed(string action, real value)\n    function color(key) {\n        if (key === \"color.text\") return \"#e4ece6\"\n        if (key.indexOf(\"textMuted\") >= 0) return \"#9bb3ae\"\n        if (key.indexOf(\"accent\") >= 0 || key === \"color.primary\") return \"#a9e0b7\"\n        if (key.indexOf(\"border\") >= 0) return \"#456265\"\n        if (key.indexOf(\"page.background\") >= 0) return \"#17292c\"\n        return \"#263c3e\"\n    }\n    function number(key) { return key.indexOf(\"font\") >= 0 ? (key.endsWith(\"lg\") ? 20 : 14) : key.indexOf(\"height\") >= 0 ? 46 : 8 }\n    function surface(key) { return {} }\n    function text(key, fallback) { return fallback }\n    function value(key, fallback) { return values[key] === undefined ? fallback : values[key] }\n    function setValue(key, v) { values[key] = v }\n    function get(key, fallback) { return saveValues[key] === undefined ? fallback : saveValues[key] }\n    function set(key, value) { saveValues[key] = value }\n    function contains(key) { return saveValues[key] !== undefined }\n    function registerMigration(fromVersion, toVersion, callback) { migrations[fromVersion] = callback }\n    function hasStoredSlot(slot) { return stored }\n    function load(slot) {\n        if (!stored || corrupt) return false\n        if (migrations[schema]) saveValues = migrations[schema](saveValues)\n        return true\n    }\n    function save(slot) { if (corrupt) return false; commits++; return true }\n    function autosave() { return save(\"autosave\") }\n    function nextInt(a,b) { return a }\n    function play(name) { return false }\n    function playUrl(name, gain) { return false }\n    function playEffect(name) { return false }\n    function preload(name) {}\n    function light() {}\n    function medium() {}\n    function heavy() {}\n    function counter(name) { return 0 }\n    function increment(name, value) {}\n    function unlock(name) {}\n}"

SERVICES = ("GameSave GameTheme GameI18n GameSettings Viewport Haptics GameInput "
            "GameRandom GameStats Achievements Audio GameAudio Lifecycle").split()


def spin(app, milliseconds=80):
    end = time.monotonic() + milliseconds / 1000
    while time.monotonic() < end:
        app.processEvents()
        time.sleep(0.003)


def fixture(mega):
    now = int(time.time() * 1000)
    if mega:
        state = {"format": 4, "factoryCores": 100000, "blueprints": 12345, "masterSchematics": 500,
                 "credits": 123456789, "rawMaterial": 20, "factoryLevel": 25,
                 "machines": {"collector": 3, "press": 2, "assembler": 3, "freight": 2}}
        return 4, {"state_v4_json": json.dumps(state), "savedAtMs": now}
    return 2, {"coins": 12345, "crowns": 12, "research": 200, "ore": 7, "parts": 9,
               "circuits": 5, "goods": 4, "robots": 3, "reputation": 20,
               "storageLevel": 3, "efficiencyLevel": 2, "lastPersistMs": now,
               "lines": [{"level": 3, "manager": False, "progress": 0} for _ in range(6)],
               "contract": {"kind": "goods", "amount": 10, "progress": 3, "reward": 120, "research": 2}}


def evaluate(engine, statement):
    result = engine.evaluate(statement)
    if result.isError():
        raise AssertionError(result.toString())
    return result.toVariant()


def measure(app, window, scene, engine, duration):
    viewport = scene.findChild(QObject, "factoryViewport")
    assert viewport is not None
    evaluate(engine, "scene.stepZoom(2.2)")
    spin(app, 300)
    frames = []
    callback = lambda: frames.append(time.perf_counter())
    window.frameSwapped.connect(callback)
    start = time.perf_counter()
    next_step = start
    while (now := time.perf_counter()) - start < duration:
        if now >= next_step:
            dt = now - start
            evaluate(engine, f"scene.changeZoom({2.15 + 0.18 * math.sin(dt * 0.7)})")
            width = max(0, viewport.property("contentWidth") - viewport.property("width"))
            height = max(0, viewport.property("contentHeight") - viewport.property("height"))
            viewport.setProperty("contentX", width * (0.5 + 0.45 * math.sin(dt * 1.5)))
            viewport.setProperty("contentY", height * (0.5 + 0.45 * math.cos(dt * 1.2)))
            next_step = now + 1 / 60
        app.processEvents()
        time.sleep(0.001)
    window.frameSwapped.disconnect(callback)
    intervals = sorted((b - a) * 1000 for a, b in zip(frames, frames[1:]))
    assert len(intervals) >= duration * 20, "Insufficient frame samples"
    return intervals[math.ceil(len(intervals) * 0.95) - 1], len(intervals)


def verify(app, game, package, previews, benchmark):
    mega = game == "pocket_factory"
    mount = f"/mods/{game}"
    assert QResource.registerResource(str(package), mount), package
    for case in ("new", "legacy", "unreadable"):
        engine = QQmlEngine()
        service_component = QQmlComponent(engine)
        service_component.setData(SERVICE.encode(), QUrl("file:///fixture.qml"))
        service = service_component.create()
        assert service is not None, service_component.errors()
        service.setProperty("gameId", game)
        if case != "new":
            schema, data = fixture(mega)
            service.setProperty("stored", True)
            service.setProperty("corrupt", case == "unreadable")
            service.setProperty("schema", schema)
            service.setProperty("saveValues", engine.toScriptValue(data))
        for name in SERVICES:
            engine.rootContext().setContextProperty(name, service)

        window = QQuickWindow()
        width = 390 if case == "new" else 1000
        service.setProperty("safeWidth", width)
        window.resize(width, 760)
        component = QQmlComponent(engine, QUrl(f"qrc:{mount}/Main.qml"))
        item = component.create()
        assert item is not None, [e.toString() for e in component.errors()]
        item.setParentItem(window.contentItem())
        item.setWidth(width)
        item.setHeight(760)
        window.show()
        spin(app, 260)

        progress = item.findChild(QObject, "factoryProgress")
        prefs = item.findChild(QObject, "factoryPreferences")
        for name, instance in (("game", item), ("progress", progress), ("prefs", prefs)):
            assert instance is not None, (game, name)
            engine.globalObject().setProperty(name, engine.newQObject(instance))

        if mega:
            item.setProperty("simulationSuspended", True)
        page = "activeTab" if mega else "page"
        for index in (1, 2, 3, 4, 0):
            item.setProperty(page, index)
            spin(app, 40)
        if case == "unreadable":
            assert item.property("saveBlocked") and service.property("commits") == 0
        else:
            assert service.property("commits") > 0
            open_zone = "openZone" if mega else "selectZone"
            evaluate(engine, f"game.{open_zone}(2)")
            assert item.property(page) == 1
            item.setProperty(page, 0)
            if case == "legacy":
                assert item.property("factoryCores" if mega else "crowns") == (100000 if mega else 12)
                assert item.property("blueprints" if mega else "research") == (12345 if mega else 200)
                evaluate(engine, "progress.buyPatent(0); progress.equip(0);")
                assert evaluate(engine, "progress.state.patents[0]") == 1
                assert evaluate(engine, "progress.state.equipped.length") == 1
                evaluate(engine, "progress.commit({projects:[3,3,3,3,3]})")
                assert progress.property("district") == 4
                balance_property = "credits" if mega else "coins"
                balance = item.property(balance_property)
                evaluate(engine, "progress.acceptOrder(0); progress.record({made: 1e6}); progress.record({shipped: 1e6});")
                reward = evaluate(engine, "progress.state.order.reward")
                evaluate(engine, "progress.claim(); progress.claim();")
                assert item.property(balance_property) == balance + reward
                assert evaluate(engine, "progress.state.completed[0]") == 0

            for mode in (0, 1, 2):
                balance = item.property("credits" if mega else "coins")
                evaluate(engine, f"prefs.set('factoryScene', {mode})")
                spin(app, 150)
                assert prefs.property("mode") == mode
                loader = item.findChild(QObject, "factorySceneLoader")
                assert loader.property("active") == (mode != 0)
                scene = loader.property("item")
                assert (scene is not None) == (mode != 0), (game, case, mode)
                assert item.property("credits" if mega else "coins") == balance
                if scene is not None:
                    engine.globalObject().setProperty("scene", engine.newQObject(scene))
                    evaluate(engine, "scene.stepZoom(1.5); scene.stepZoom(1/1.5)")
                    assert evaluate(engine, "scene.details.length") <= (24 if mode == 1 else 48)
                    if case == "legacy" and mode == 1 and benchmark:
                        p95, frames = measure(app, window, scene, engine, benchmark)
                        print(f"{game}: Low mode p95 {p95:.2f} ms ({frames} samples, {benchmark:g} s)")
                        assert p95 <= 33, (game, p95)
                if previews and mode == 2:
                    evaluate(engine, "scene.stepZoom(1/3)")
                    spin(app, 260)
                    assert window.grabWindow().save(str(previews / f"{game}-{case}.png"))
        window.hide()
        item.setParentItem(None)
        item.deleteLater()
        spin(app, 20)
        print(f"{game} {case} passed")
    QResource.unregisterResource(str(package), mount)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("community", type=Path, nargs="?")
    parser.add_argument("--mega", type=Path)
    parser.add_argument("--previews", type=Path)
    parser.add_argument("--benchmark", type=float, default=0, metavar="SECONDS")
    args = parser.parse_args()
    if args.previews:
        args.previews.mkdir(parents=True, exist_ok=True)
    app = QGuiApplication([])
    font = Path(os.environ.get("WINDIR", "")) / "Fonts/segoeui.ttf"
    if font.is_file():
        font_id = QFontDatabase.addApplicationFont(str(font))
        families = QFontDatabase.applicationFontFamilies(font_id)
        if families:
            app.setFont(QFont(families[0]))
    issues = []

    def messages(kind, context, message):
        if "qrc:/mods/" in message and any(word in message for word in
                ("ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Cannot open", "Unable to assign")):
            issues.append(message)

    qInstallMessageHandler(messages)
    if args.community:
        verify(app, "pocket_factory_community", args.community.resolve(), args.previews, args.benchmark)
    if args.mega:
        verify(app, "pocket_factory", args.mega.resolve(), args.previews, args.benchmark)
    if not (args.community or args.mega):
        parser.error("provide at least one RCC package")
    assert not issues, "\n".join(dict.fromkeys(issues))


if __name__ == "__main__":
    main()
