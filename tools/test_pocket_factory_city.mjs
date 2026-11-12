import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import vm from "node:vm";

const directories = process.argv.slice(2);
assert.ok(directories.length, "Provide one or more Pocket Factory game directories.");
const json = (file) => JSON.parse(readFileSync(file, "utf8"));
const tuple = (value) => JSON.parse(JSON.stringify(value));

for (const directory of directories) {
    const manifest = json(path.join(directory, "manifest.json"));
    const mega = manifest.id === "pocket_factory";
    const source = readFileSync(path.join(directory, "city/CityData.js"), "utf8");
    const city = vm.createContext({});
    vm.runInContext(source.replace(/^\.pragma library\s*/, ""), city);
    assert.equal(manifest.version, "4.0.0");
    assert.equal(manifest.min_app_version, "0.7.3");
    assert.equal(manifest.save_version, mega ? 5 : 3);
    assert.equal(city.layout.length, 7);
    assert.ok(city.layout.every((tile) => tile.length === 5 && tile[4] >= 0 && tile[4] <= 3));
    assert.equal(city.patents.length, 12);
    assert.equal(city.products.length, 12);
    assert.equal(city.orders.length, 8);
    assert.equal(city.projects.length, 5);

    const fresh = city.normalize(null);
    const thresholds = mega ? [10, 100, 1000, 100000] : [1, 3, 6, 12];
    assert.equal(city.districtFor(fresh, 0, mega), 0);
    thresholds.slice(0, 3).forEach((value, index) => {
        assert.equal(city.districtFor(fresh, value - 1, mega), index);
        assert.equal(city.districtFor(fresh, value, mega), index + 1);
    });
    assert.equal(city.districtFor(fresh, thresholds[3], mega), 3);
    fresh.projects = [3, 3, 3, 3, 3];
    assert.equal(city.districtFor(fresh, thresholds[3], mega), 4);
    const persistent = city.normalize({ district: 4, equipped: [0, 1, 2, 3], patents: [3, 3, 3, 3] });
    assert.equal(city.districtFor(persistent, 0, mega), 4);
    assert.deepEqual(tuple(persistent.equipped), [0, 1]);
    assert.ok(Math.abs(city.bonus(persistent, 0) - 0.15) < 1e-9);
    assert.equal(city.bonus(persistent, 2), 0);
    assert.equal(city.stockStatus(1, 2, 100, 0), 1);
    assert.equal(city.stockStatus(7, 2, 100, 1), 3);
    assert.equal(city.stockStatus(25, 2, 100, 1), 0);

    const lots = city.dispatchLots(fresh.routeStock, 1, 4, 5, 2);
    assert.equal(lots.lots[5], 3);
    assert.equal(lots.families[1], 1);
    const afterSwitch = city.dispatchLots(lots.lots, 3, 0, 0, 1);
    assert.equal(afterSwitch.families[0], 0);
    assert.equal(afterSwitch.families[1], 1);

    let order = city.orderOffer(0, 0, 0);
    assert.equal(city.orderProgress(order, { shipped: order.target }), order);
    order = city.orderProgress(order, { made: order.target });
    assert.equal(order.stage, 1);
    order = city.orderProgress(order, { shipped: order.target });
    assert.equal(order.stage, 2);
    assert.equal(city.orderProgress(order, { shipped: 1e12 }), order);
    assert.equal(city.normalize({ order, completed: [0] }).order, null);

    if (mega) {
        const full = [0, 100, 100];
        const step = city.flowStep(full, [100, 100, 100], [0, 0, 0], [10, 10, 10, 0], [2, 2, 1], 1, false);
        assert.deepEqual(tuple(step), [10, 0, 0, 0]);
        assert.deepEqual(full, [10, 100, 100]);
        const shipping = [0, 100, 100];
        const priority = city.flowStep(shipping, [100, 100, 100], [0, 0, 0], [0, 0, 8, 10], [2, 2, 1], 1, true);
        assert.deepEqual(tuple(priority), [0, 0, 8, 10]);
        const large = [1e20, 1e20, 1e20];
        city.flowStep(large, [1e22, 1e22, 1e22], [1e18, 1e18, 1e18],
            [1e18, 1e18, 1e18, 1e18], [2, 2, 1.04], 30, true);
        assert.ok(large.every((amount) => amount >= 0 && Number.isFinite(amount)));
    }

    const localeDirectory = path.join(directory, "i18n");
    const catalog = json(path.join(localeDirectory, "en.json"));
    const keys = Object.keys(catalog).filter((key) => key.startsWith("city.")).sort();
    assert.ok(keys.length >= 140);
    const placeholders = (text) => (text.match(/%\d+/g) || []).sort();
    for (const locale of manifest.locales) {
        const translated = json(path.join(localeDirectory, locale + ".json"));
        assert.deepEqual(Object.keys(translated).filter((key) => key.startsWith("city.")).sort(), keys);
        for (const key of keys) assert.deepEqual(placeholders(translated[key]), placeholders(catalog[key]), key);
    }

    const qrc = readFileSync(path.join(directory, "mod.qrc"), "utf8");
    for (const asset of readdirSync(path.join(directory, "city/assets"))) {
        assert.ok(qrc.includes('alias="city/assets/' + asset + '"'), asset);
    }
    console.log(manifest.id + ": city mechanics, balance invariants, resources and localization parity passed");
}
