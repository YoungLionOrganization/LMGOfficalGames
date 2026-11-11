import QtQuick
Rectangle {
    id: root
    default property alias contentData: layer.data
    property string surfaceToken: "surface.card"
    property var spec: GameTheme.surface(surfaceToken)
    color: spec && spec.color !== undefined ? spec.color : GameTheme.color("color.surfaceRaised")
    radius: spec && spec.radius !== undefined ? Number(spec.radius) : GameTheme.number("alias.card.radius")
    border.width: spec && spec.borderWidth !== undefined ? Number(spec.borderWidth) : GameTheme.number("alias.card.borderWidth")
    border.color: spec && spec.border !== undefined ? spec.border : GameTheme.color("color.border")
    gradient: spec && spec.fillType === "gradient" && spec.gradient ? themedGradient : null
    Gradient {
        id: themedGradient
        orientation: root.spec && root.spec.gradient && root.spec.gradient.orientation === "horizontal" ? Gradient.Horizontal : Gradient.Vertical
        GradientStop { position: 0.0; color: root.spec && root.spec.gradient && root.spec.gradient.start !== undefined ? root.spec.gradient.start : root.color }
        GradientStop { position: 0.5; color: root.spec && root.spec.gradient && root.spec.gradient.middle !== undefined ? root.spec.gradient.middle : root.color }
        GradientStop { position: 1.0; color: root.spec && root.spec.gradient && root.spec.gradient.end !== undefined ? root.spec.gradient.end : root.color }
    }
    Image {
        anchors.fill: parent
        visible: !!root.spec && root.spec.texture !== undefined && String(root.spec.texture).length > 0
        source: visible ? String(root.spec.texture) : ""
        opacity: root.spec && root.spec.textureOpacity !== undefined ? Number(root.spec.textureOpacity) : 0
        fillMode: Image.Tile
        asynchronous: true
    }
    Item { id: layer; anchors.fill: parent }
}
