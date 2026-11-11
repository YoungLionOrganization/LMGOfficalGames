import QtQuick

UiPanel {
    id: root

    property bool compact: false
    property string coinsLabel: ""
    property string coinsValue: ""
    property string energyLabel: ""
    property string energyValue: ""
    property string dayLabel: ""
    property string dayValue: ""
    property string seasonLabel: ""
    property string seasonValue: ""
    property string weatherLabel: ""
    property string weatherValue: ""
    property string levelLabel: ""
    property string levelValue: ""
    property string reputationLabel: ""
    property string reputationValue: ""

    implicitHeight: hudFlow.implicitHeight + 12
    surfaceToken: "surface.control"

    Flow {
        id: hudFlow
        anchors.fill: parent
        anchors.margins: 6
        spacing: 5

        HudChip { label: root.coinsLabel; value: root.coinsValue; valueColorToken: "color.special" }
        HudChip { label: root.energyLabel; value: root.energyValue; valueColorToken: "color.primary" }
        HudChip { label: root.dayLabel; value: root.dayValue }
        HudChip { label: root.seasonLabel; value: root.seasonValue; valueColorToken: "color.accent" }
        HudChip { label: root.weatherLabel; value: root.weatherValue }
        HudChip { visible: !root.compact; label: root.levelLabel; value: root.levelValue }
        HudChip { visible: !root.compact; label: root.reputationLabel; value: root.reputationValue; valueColorToken: "color.accent" }
    }
}
