import QtQuick
import QtQuick.Controls
import QtMultimedia

import org.mauikit.controls as Maui

Maui.GridBrowserDelegate
{
    id: control

    property bool fit : false

    maskRadius: 0
    draggable: true

    tooltipText: model.url.replace("file://", "")
    iconSizeHint: Maui.Style.iconSizes.small

    label1.text: model.title

    iconSource: "view-preview"
    // Don't fall back to model.url — loading full-size originals for every
    // item in the grid causes massive RAM spikes (GiBs for large collections).
    // When thumbnail is empty the icon fallback shows instead, and the C++
    // thumbnail generator will update model.thumbnail once it's ready.
    imageSource: model.thumbnail ?? ""

    fillMode: control.fit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
    template.labelSizeHint: 40
    template.iconComponent: (model.format === "gif" || model.format === "avif") && control.hovered ? _animatedComponent :  _iconComponent

    Rectangle
    {
        anchors.fill: parent
        color: "transparent"
        radius: control.radius
        border.width: (control.hovered || control.isCurrentItem || control.checked) ? 0 : 1
        border.color: Qt.rgba(Maui.Theme.textColor.r, Maui.Theme.textColor.g, Maui.Theme.textColor.b, 0.15)
        z: 1
    }

    Loader
    {
        asynchronous: true
        active: (model.format === "gif" || model.format === "avif") && !control.hovered
        anchors.centerIn: parent
        height: 32
        width: 32

        sourceComponent: Rectangle
        {
            color: Maui.Theme.backgroundColor
            radius: height/2

            Maui.Icon
            {
                source: "media-playback-start"
                color : Maui.Theme.textColor
                height: 16
                width: 16
                anchors.centerIn: parent
            }
        }
    }

    Component
    {
        id: _iconComponent

        Maui.IconItem
        {
            id: _iconItem
            iconSource: control.iconSource
            imageSource: model.thumbnail ?? ""

            highlighted: control.isCurrentItem
            hovered: control.hovered
            smooth: control.smooth
            iconSizeHint: control.iconSizeHint
            imageSizeHint: control.imageSizeHint

            fillMode: control.fillMode
            maskRadius: control.maskRadius

            imageWidth: control.imageWidth
            imageHeight: control.imageHeight

            isMask: true
            image.cache: false
            image.autoTransform: true
        }
    }

    Component
    {
        id: _animatedComponent
        AnimatedImage
        {
            source: control.imageSource
            fillMode:  control.fillMode
            autoTransform: true
            asynchronous: true
            onStatusChanged: playing = (status == AnimatedImage.Ready)
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
        }
    }
}
