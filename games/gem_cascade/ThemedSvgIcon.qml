import QtQuick

Canvas {
    id: root
    property url source
    property int themeRevision: 0
    function themeColor(token) {
        var touch = themeRevision
        var fallback = token === "color.text" ? "#f2f5f8" : "#6c8cff"
        try {
            if (typeof GameTheme !== "undefined") {
                var v = GameTheme.color(token)
                if (v !== undefined && v !== null && String(v).length > 0) return v
            }
        } catch (e) {}
        return fallback
    }
    property color tint: themeColor("color.primary")
    property color secondaryTint: themeColor("color.text")
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
    onThemeRevisionChanged: requestPaint()
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
