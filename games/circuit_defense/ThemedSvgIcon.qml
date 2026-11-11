import QtQuick

Canvas {
    id: root
    property url source
    property color tint: GameTheme.color("color.primary")
    property color secondaryTint: GameTheme.color("color.text")
    antialiasing: true
    renderTarget: Canvas.Image

    function ensureLoaded() {
        if (!source || String(source).length === 0)
            return
        if (!isImageLoaded(source))
            loadImage(source)
        else
            requestPaint()
    }

    onSourceChanged: ensureLoaded()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onImageLoaded: requestPaint()
    Component.onCompleted: ensureLoaded()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (!source || String(source).length === 0 || !isImageLoaded(source)) {
            ensureLoaded()
            return
        }
        ctx.drawImage(source, 0, 0, width, height)
        ctx.globalCompositeOperation = "source-in"
        ctx.fillStyle = tint
        ctx.fillRect(0, 0, width, height)
        ctx.globalCompositeOperation = "source-over"
    }
}
