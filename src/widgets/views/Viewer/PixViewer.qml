// Copyright 2018-2020 Camilo Higuita <milo.h@aol.com>
// Copyright 2018-2020 Nitrux Latinoamericana S.C.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import org.mauikit.controls as Maui
import org.mauikit.filebrowsing as FB

import org.maui.pix as Pix

import "../../../view_models"


Maui.Page
{
    id: control
    property bool useInternalChrome: true

    Keys.forwardTo: viewer
    Keys.enabled: true
    Keys.onPressed: (event) =>
                    {

                        if((event.key == Qt.Key_F && (event.modifiers & Qt.ControlModifier) ) || event.key === Qt.Key_F4)
                        {
                            showFullScreen()
                            event.accepted = true
                        }

                        if((event.key == Qt.Key_Escape) && root.isFullScreen)
                        {
                            toggleFullscreen()
                            event.accepted = true
                        }


                        if((event.key == Qt.Key_T && (event.modifiers & Qt.ControlModifier) ))
                        {
                            focusTagsBar()
                            event.accepted = true
                        }
                    }

    signal closeRequested()
    signal editRequested(string url)

    readonly property alias viewer : viewer
    readonly property alias holder : holder

    readonly property alias model : viewer.model
    property Maui.BaseModel sourceModel: null
    readonly property var sourceGalleryList: control.sourceModel ? control.sourceModel.list : null
    readonly property bool sourceModelLoading: sourceGalleryList && sourceGalleryList.status === Pix.GalleryList.Loading

    property bool currentPicFav: false
    property var currentPic : ({url: "", title: ""})
    readonly property string currentPicUrl: currentPic && currentPic.url ? String(currentPic.url) : ""
    readonly property string currentPicTitle: currentPic && currentPic.title ? String(currentPic.title) : ""
    property int currentPicIndex : 0
    property bool doodle : false
    onCurrentPicChanged:
    {
        control.currentPicFav = control.currentPicUrl.length > 0 && FB.Tagging.isFav(control.currentPicUrl)
        root.title = control.currentPicTitle
    }

    property bool slideshowActive: false
    onSlideshowActiveChanged: if (!slideshowActive) { _advanceTimer.stop(); _transitionOverlay.opacity = 0 }

    // Fade duration in ms — must match the Behavior on _transitionOverlay.opacity.
    readonly property int _fadeDuration: 600

    Timer
    {
        id: _slideshowTimer
        // Each slide occupies the full interval. The transition (2 × _fadeDuration)
        // is baked into that time: image is visible for (interval*1000 - 2*fade) ms.
        interval: viewerSettings.slideshowInterval * 1000
        running: control.slideshowActive && viewer.count > 1
        repeat: true
        onTriggered: _transitionOverlay.fadeAndAdvance()
    }

    // Fires once the fade-to-black is complete; advances the image while the
    // screen is fully dark, then fades back in.
    Timer
    {
        id: _advanceTimer
        interval: control._fadeDuration
        repeat: false
        onTriggered:
        {
            if (!control.slideshowActive)
                return
            if (!viewerSettings.slideshowLoop && control.currentPicIndex >= control.viewer.count - 1)
                control.slideshowActive = false
            else
                control.next()
            _transitionOverlay.opacity = 0
        }
    }

    Connections
    {
        target: control.sourceModel
        ignoreUnknownSignals: true

        function onCountChanged()
        {
            if (control.sourceModelLoading)
                return

            control.syncFromSourceModel()
        }
    }

    Connections
    {
        target: control.sourceGalleryList
        ignoreUnknownSignals: true

        function onStatusChanged()
        {
            if (control.sourceModelLoading)
                return

            control.syncFromSourceModel()
        }
    }

    PixMenu
    {
        id: _picMenu

        index: control.currentPicIndex
        model: viewer.model
    }

    onGoBackTriggered: control.closeRequested()

    title: currentPicTitle
    showTitle: true

    Maui.Controls.showCSD: true
    altHeader: Maui.Handy.isMobile
    floatingHeader: true
    autoHideHeader: viewer.imageZooming
    headerMargins: Maui.Style.contentMargins

    headBar.visible: useInternalChrome

    headBar.leftContent: [
        ToolButton
        {
            icon.name: "go-previous"
            onClicked: control.closeRequested()
        },

        ToolSeparator {
            bottomPadding: 10
            topPadding: 10
        },

        ToolButton
        {
            icon.name: "view-fullscreen"
            checked: root.fullScreen
            onClicked: root.fullScreen ? root.showNormal() : root.showFullScreen()
        },

        ToolButton
        {
            icon.name: "draw-freehand"
            onClicked:
            {
                if (control.currentPicUrl.length > 0)
                    control.editRequested(control.currentPicUrl)
            }
        }
    ]

    headBar.rightContent: [
        ToolButton
        {
            visible: control.slideshowActive
            icon.name: "media-playback-stop"
            onClicked: control.slideshowActive = false
        },

        ToolButton
        {
            icon.name: "documentinfo"
            onClicked: getFileInfo(control.currentPicUrl)
        },

        ToolButton
        {
            icon.name: "edit-delete"
            onClicked: removeFiles([control.currentPicUrl])
        }
    ]

    headBar.farRightContent: [
        Item
        {
            implicitWidth: Maui.Style.iconSizes.medium
            implicitHeight: parent ? parent.height : Maui.Style.rowHeight

            Rectangle
            {
                width: 1
                radius: width / 2
                color: Maui.Theme.textColor
                opacity: 0.3
                anchors.centerIn: parent
                height: Math.max(parent.height - 20, 12)
            }
        },

        Maui.ToolButtonMenu
        {
            icon.name: "overflow-menu"

            MenuItem
            {
                text: i18n("Shortcuts")
                icon.name: "configure-shortcuts"
                onTriggered: ApplicationWindow.window.openShortcutsDialog()
            }

            MenuItem
            {
                text: i18n("Preferences")
                icon.name: "settings-configure"
                onTriggered: ApplicationWindow.window.openSettingsDialog()
            }

            MenuItem
            {
                text: i18n("About")
                icon.name: "documentinfo"
                onTriggered: Maui.App.aboutDialog()
            }
        }
    ]

    headerColumn: Maui.ToolBar
    {
        id: _alertBar
        visible: (_watcher.modified || _watcher.deleted)
        width: parent ? parent.width : 0

        background: Rectangle
        {
            color: Maui.Theme.alternateBackgroundColor
            opacity: 0.75
            radius: Maui.Style.radiusV
        }

        Pix.FileWatcher
        {
            id: _watcher

            property bool modified: false
            property bool deleted : false
            property bool autoRefresh : false

            url: currentPicUrl
            onFileModified:
            {
                if(autoRefresh)
                {
                    viewer.reloadCurrentItem()
                    _watcher.modified = false
                }else
                {
                    modified = true
                }
            }
            onFileDeleted: deleted = true

            onUrlChanged:
            {
                deleted = false
                modified = false
            }
        }

        middleContent: Maui.ListItemTemplate
        {
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconSource: "dialog-warning"
            label1.text: i18n("The current image file has been modified or removed externally")
            label2.text: _watcher.deleted ? i18n("The image was deleted") : i18n("The image was modified")
        }

        rightContent: [
            Button
            {
                text: i18n("Reload")
                visible: _watcher.modified
                Maui.Controls.status: Maui.Controls.Negative
                onClicked:
                {
                    viewer.reloadCurrentItem()
                    _watcher.modified = false
                }
            },

            Button
            {
                text: i18n("Auto Reload")
                Maui.Controls.status: Maui.Controls.Neutral

                visible: _watcher.modified
                onClicked:
                {
                    viewer.reloadCurrentItem()
                    _watcher.autoRefresh = true
                    _watcher.modified = false
                }
            },

            Button
            {
                text: i18n("Save")
                visible: _watcher.deleted
                Maui.Controls.status: Maui.Controls.Positive

                onClicked: saveAs([currentPicUrl])
            }
        ]
    }

    Maui.Holder
    {
        id: holder
        visible: viewer.count === 0 /*|| viewer.currentItem.status !== Image.Ready*/
        anchors.fill: parent
        emoji: "image-x-generic"
        isMask: true
        title : i18n("No Pics!")
        body: i18n("Open an image from your collection")
    }

    ColumnLayout
    {
        height: parent.height
        width: parent.width
        spacing: 0

        Viewer
        {
            id: viewer
            sourceModel: control.sourceModel
            visible: !holder.visible
            Layout.fillHeight: true
            Layout.fillWidth: true

            MouseArea
            {
                id: _prevMouseArea
                visible: viewer.count > 1
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.round(parent.width * 0.08)
                propagateComposedEvents: true
                onClicked: control.previous()

                HoverHandler { id: _prevHover }

                Rectangle
                {
                    opacity: _prevHover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Maui.Style.units.shortDuration } }
                    anchors.left: parent.left
                    anchors.leftMargin: Maui.Style.space.small
                    anchors.verticalCenter: parent.verticalCenter
                    width: Maui.Style.iconSizes.big + Maui.Style.space.medium
                    height: width
                    radius: height / 2
                    color: _prevMouseArea.pressed ? Maui.Theme.highlightColor : Qt.rgba(0, 0, 0, 0.4)

                    Maui.Icon
                    {
                        anchors.centerIn: parent
                        source: "go-previous"
                        color: "white"
                        height: Maui.Style.iconSizes.medium
                        width: height
                    }
                }
            }

            MouseArea
            {
                id: _nextMouseArea
                visible: viewer.count > 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.round(parent.width * 0.08)
                propagateComposedEvents: true
                onClicked: control.next()

                HoverHandler { id: _nextHover }

                Rectangle
                {
                    opacity: _nextHover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Maui.Style.units.shortDuration } }
                    anchors.right: parent.right
                    anchors.rightMargin: Maui.Style.space.small
                    anchors.verticalCenter: parent.verticalCenter
                    width: Maui.Style.iconSizes.big + Maui.Style.space.medium
                    height: width
                    radius: height / 2
                    color: _nextMouseArea.pressed ? Maui.Theme.highlightColor : Qt.rgba(0, 0, 0, 0.4)

                    Maui.Icon
                    {
                        anchors.centerIn: parent
                        source: "go-next"
                        color: "white"
                        height: Maui.Style.iconSizes.medium
                        width: height
                    }
                }
            }

            // Slideshow fade-to-black overlay. Sits above all viewer content
            // (z: 10) but below the page header. Starts transparent; becomes
            // opaque during transitions so the ListView snap is invisible.
            Rectangle
            {
                id: _transitionOverlay
                anchors.fill: parent
                color: "black"
                opacity: 0
                z: 10
                visible: control.slideshowActive

                Behavior on opacity
                {
                    NumberAnimation
                    {
                        duration: control._fadeDuration
                        easing.type: Easing.InOutQuad
                    }
                }

                function fadeAndAdvance()
                {
                    opacity = 1       // triggers fade-to-black animation
                    _advanceTimer.start()  // fires after _fadeDuration ms
                }
            }

        }

        Loader
        {
            id: _tagsbarLoader
            asynchronous: true
            active: !holder.visible && viewerSettings.tagBarVisible && !fullScreen
            Layout.fillWidth: true

            sourceComponent: FB.TagsBar
            {
                allowEditMode: true
                list.urls: currentPicUrl.length > 0 ? [currentPicUrl] : []
                list.strict: false

                onTagRemovedClicked: (index) => list.removeFromUrls(index)
                onTagsEdited:(tags) =>
                             {
                                 list.updateToUrls(tags)
                                 viewer.forceActiveFocus()
                             }

                onTagClicked: (tag) => openFolder("tags:///"+tag)
            }
        }
    }

    Item
    {
        id: _previewBar
        visible: viewerSettings.previewBarVisible && !holder.visible && viewer.count > 1
        z: 9
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Maui.Style.contentMargins
        anchors.rightMargin: Maui.Style.contentMargins
        anchors.bottom: parent.bottom
        anchors.bottomMargin: viewer.imageZooming || viewer.focusedMode
                              ? -height
                              : ((_tagsbarLoader.active && _tagsbarLoader.item)
                                 ? _tagsbarLoader.height + Maui.Style.space.small
                                 : Maui.Style.space.small)
        height: Math.min(72, Math.max(control.height * 0.12, 72))
        opacity: viewer.imageZooming || viewer.focusedMode ? 0 : 1

        Behavior on anchors.bottomMargin
        {
            NumberAnimation
            {
                duration: Maui.Style.units.longDuration
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on opacity
        {
            NumberAnimation
            {
                duration: Maui.Style.units.longDuration
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle
        {
            id: _previewBarBackground
            anchors.fill: parent
            color: Maui.Theme.backgroundColor
            border.color: Maui.Theme.alternateBackgroundColor
            border.pixelAligned: false
            radius: Maui.Style.radiusV
            antialiasing: true

            ShaderEffectSource
            {
                id: _previewBarEffect
                anchors.fill: parent
                visible: false
                textureSize: Qt.size(_previewBar.width, _previewBar.height)
                sourceItem: viewer
                sourceRect: _previewBar.mapToItem(viewer, Qt.rect(0, 0, _previewBar.width, _previewBar.height))
            }

            Loader
            {
                asynchronous: true
                active: Maui.Style.enableEffects && GraphicsInfo.api !== GraphicsInfo.Software
                anchors.fill: parent
                sourceComponent: MultiEffect
                {
                    opacity: 0.2
                    saturation: -0.5
                    blurEnabled: true
                    blurMax: 32
                    blur: 1.0
                    autoPaddingEnabled: true
                    source: _previewBarEffect
                }
            }

            layer.enabled: radius > 0 && GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect
            {
                maskEnabled: true
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
                maskSpreadAtMax: 0.0
                maskThresholdMax: 1.0
                maskSource: ShaderEffectSource
                {
                    sourceItem: Rectangle
                    {
                        width: _previewBarBackground.width
                        height: _previewBarBackground.height
                        radius: _previewBarBackground.radius
                    }
                }
            }
        }

        GalleryRoll
        {
            anchors.fill: parent
            anchors.margins: Maui.Style.defaultPadding
            model: control.model
            currentIndex: control.currentPicIndex
            onPicClicked: (index) => view(index)
            background: Item {}
        }
    }

    function next()
    {
        var index = control.currentPicIndex

        if(index < control.viewer.count-1)
            index++
        else
            index= 0

        view(index)
    }

    function previous()
    {
        var index = control.currentPicIndex

        if(index > 0)
            index--
        else
            index = control.viewer.count-1

        view(index)
    }

    function incrementCurrentIndex()
    {
        control.currentPicIndex++
        control.currentPic = control.model.get(control.currentPicIndex) ?? ({url: "", title: ""})
    }

    function decrementCurrentIndex()
    {
        control.currentPicIndex--
        control.currentPic = control.model.get(control.currentPicIndex) ?? ({url: "", title: ""})
    }

    function view(index : int)
    {
        {
            if (index !== control.currentPicIndex)
                viewer.prepareCurrentItemForNavigation()

            control.currentPicIndex = index
            control.currentPic = control.model.get(control.currentPicIndex) ?? ({url: "", title: ""})
            viewer.forceActiveFocus()
        }
    }

    function focusTagsBar()
    {
        _tagsbarLoader.item.goEditMode()
    }

    function removeUrls(urls)
    {
        const cleanUrls = (urls || []).map((url) => String(url)).filter((url) => url.length > 0)
        if (cleanUrls.length === 0)
            return

        const currentUrl = control.currentPicUrl
        const currentIndex = control.currentPicIndex
        const currentRemoved = cleanUrls.includes(currentUrl)
        const remainingUrls = control.model.getAll()
                                         .map((item) => item.url ? String(item.url) : "")
                                         .filter((url) => url.length > 0 && !cleanUrls.includes(url))

        if (remainingUrls.length === 0)
        {
            control.slideshowActive = false
            control.currentPicIndex = 0
            control.currentPic = ({url: "", title: ""})
            control.closeRequested()
            return
        }

        if (control.sourceModel)
            return

        viewer.clear()
        viewer.appendPics(remainingUrls)

        if (currentRemoved)
        {
            view(Math.min(currentIndex, remainingUrls.length - 1))
            return
        }

        const preservedIndex = remainingUrls.indexOf(currentUrl)
        view(preservedIndex >= 0 ? preservedIndex : Math.min(currentIndex, remainingUrls.length - 1))
    }

    function syncFromSourceModel(preferredIndex = -1)
    {
        if (!control.sourceModel)
            return

        // Auto-reload clears the source model before repopulating it. Ignore that
        // transient empty/loading phase so the viewer does not close itself.
        if (preferredIndex < 0 && control.sourceModelLoading)
            return

        const sourceUrls = control.sourceModel.getAll()
                                            .map((item) => item.url ? String(item.url) : "")
                                            .filter((url) => url.length > 0)

        const currentUrl = control.currentPicUrl
        const fallbackIndex = preferredIndex >= 0 ? preferredIndex : control.currentPicIndex

        if (sourceUrls.length === 0)
        {
            control.slideshowActive = false
            control.currentPicIndex = 0
            control.currentPic = ({url: "", title: ""})
            control.closeRequested()
            return
        }

        if (preferredIndex >= 0)
        {
            view(Math.min(preferredIndex, sourceUrls.length - 1))
            return
        }

        const preservedIndex = currentUrl.length > 0 ? sourceUrls.indexOf(currentUrl) : -1
        view(preservedIndex >= 0 ? preservedIndex : Math.min(fallbackIndex, sourceUrls.length - 1))
    }

}
