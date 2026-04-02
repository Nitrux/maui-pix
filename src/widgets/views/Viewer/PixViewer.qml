// Copyright 2018-2020 Camilo Higuita <milo.h@aol.com>
// Copyright 2018-2020 Nitrux Latinoamericana S.C.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import QtQuick.Controls
import QtQuick.Layouts

import org.mauikit.controls as Maui
import org.mauikit.filebrowsing as FB

import org.maui.pix as Pix

import "../../../view_models"


Maui.Page
{
    id: control

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

    property bool currentPicFav: false
    property var currentPic : ({})
    property int currentPicIndex : 0
    property bool doodle : false

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

    PixMenu
    {
        id: _picMenu

        index: control.currentPicIndex
        model: viewer.model
    }

    onGoBackTriggered: control.closeRequested()

    title: currentPic.title
    showTitle: true

    Maui.Controls.showCSD: true
    altHeader: Maui.Handy.isMobile
    floatingHeader: true
    autoHideHeader: viewer.imageZooming
    headerMargins: Maui.Style.contentMargins

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
            onClicked: control.editRequested(control.currentPic.url)
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
            onClicked: getFileInfo(control.currentPic.url)
        },

        ToolButton
        {
            icon.name: "edit-delete"
            onClicked: removeFiles([control.currentPic.url])
        },

        ToolSeparator {
            bottomPadding: 10
            topPadding: 10
        },

        Maui.ToolButtonMenu
        {
            icon.name: "overflow-menu"

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
        width: parent.width

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

            url: currentPic.url
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

                onClicked: saveAs([currentPic.url])
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

            Loader
            {
                id: galleryRoll

                asynchronous: true
                active: viewerSettings.previewBarVisible
                width: parent.width
                height: active ? Math.min(60, Math.max(parent.height * 0.12, 60)) : 0
                y: viewer.imageZooming || viewer.focusedMode ? parent.height :  parent.height - height

                Behavior on y
                {
                    NumberAnimation
                    {
                        duration: Maui.Style.units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }
                sourceComponent:  GalleryRoll
                {
                    visible: rollList.count > 1

                    model: control.model
                    onPicClicked: (index) => view(index)
                    currentIndex: control.currentPicIndex


                    Behavior on opacity
                    {
                        NumberAnimation
                        {
                            duration: Maui.Style.units.longDuration
                            easing.type: Easing.InOutQuad
                        }
                    }

                    padding: Maui.Style.defaultPadding
                    background: Rectangle
                    {
                        color: "black"
                        opacity: 0.7
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
                list.urls: [currentPic.url]
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
        control.currentPic = control.model.get(control.currentPicIndex)

        control.currentPicFav = FB.Tagging.isFav(control.currentPic.url)
        root.title = control.currentPic.title
    }

    function decrementCurrentIndex()
    {
        control.currentPicIndex--
        control.currentPic = control.model.get(control.currentPicIndex)

        control.currentPicFav = FB.Tagging.isFav(control.currentPic.url)
        root.title = control.currentPic.title
    }

    function view(index : int)
    {
        {
            control.currentPicIndex = index
            control.currentPic = control.model.get(control.currentPicIndex)

            control.currentPicFav = FB.Tagging.isFav(control.currentPic.url)
            root.title = control.currentPic.title
            viewer.forceActiveFocus()
        }
    }

    function focusTagsBar()
    {
        _tagsbarLoader.item.goEditMode()
    }

}


