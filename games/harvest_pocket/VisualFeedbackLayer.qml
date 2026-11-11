import QtQuick

Item {
    id: root
    property bool reducedMotion: false
    property string dayLabel: ""
    property bool transitionBusy: dayTransition.active || seasonTransition.active || weatherTransition.active
    property int pendingSeason: 0
    property string pendingWeather: "sunny"
    property string pendingSeasonLabel: ""
    property string pendingWeatherLabel: ""
    property bool pendingSeasonChanged: false

    signal commitRequested()
    signal transitionStarted()
    signal transitionFinished()

    anchors.fill: parent

    function beginDay(fromSeason, fromWeather) {
        if (transitionBusy) return false
        pendingSeason = Number(fromSeason || 0)
        pendingWeather = String(fromWeather || "sunny")
        pendingSeasonChanged = false
        transitionStarted()
        dayTransition.begin()
        return true
    }

    function forceFinish() {
        seasonTransition.cancel()
        weatherTransition.cancel()
        dayTransition.forceFinish()
    }

    function commitApplied(newSeason, newWeather, newSeasonLabel, newWeatherLabel) {
        pendingSeasonChanged = Number(newSeason) !== pendingSeason
        pendingSeason = Number(newSeason)
        pendingWeather = String(newWeather || "sunny")
        pendingSeasonLabel = String(newSeasonLabel || "")
        pendingWeatherLabel = String(newWeatherLabel || "")
        if (pendingSeasonChanged) seasonTransition.play(pendingSeason, pendingSeasonLabel)
        else weatherTransition.play(pendingWeather, pendingWeatherLabel)
    }

    DayTransition {
        id: dayTransition
        anchors.fill: parent
        reducedMotion: root.reducedMotion
        label: root.dayLabel
        onBlackoutReached: root.commitRequested()
        onFinished: root.transitionFinished()
    }

    SeasonTransition {
        id: seasonTransition
        anchors.fill: parent
        reducedMotion: root.reducedMotion
        onFinished: weatherTransition.play(root.pendingWeather, root.pendingWeatherLabel)
    }

    WeatherTransition {
        id: weatherTransition
        anchors.fill: parent
        reducedMotion: root.reducedMotion
        onFinished: dayTransition.reveal()
    }
}
