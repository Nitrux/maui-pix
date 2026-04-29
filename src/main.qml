// Copyright 2018-2020 Camilo Higuita <milo.h@aol.com>
// Copyright 2018-2020 Nitrux Latinoamericana S.C.
//
// SPDX-License-Identifier: GPL-3.0-or-later


/***
Pix  Copyright (C) 2018  Camilo Higuita
This program comes with ABSOLUTELY NO WARRANTY; for details type `show w'.
This is free software, and you are welcome to redistribute it
under certain conditions; type `show c' for details.

 This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

import QtQuick
import QtCore
import QtQuick.Controls
import QtQuick.Window

import org.mauikit.controls as Maui
import org.mauikit.filebrowsing as FB
import org.mauikit.imagetools as IT
import org.maui.pix as Pix

import "widgets"
import "widgets/views"

Maui.ApplicationWindow
{
    id: root
    title: initData

    color: "transparent"
    background: null

    readonly property bool fullScreen : root.visibility === Window.FullScreen
    readonly property alias selectionBox : _selectionBar
    property bool selectionMode : false
    property bool browserSearchExpanded: false
    property string browserSearchText: ""
    readonly property bool verticallyBiasedLayout: root.height > root.width * 1.15
    readonly property var previewSizes: ({small: 72,
                                             medium: 90,
                                             large: 120,
                                             extralarge: 160})
    readonly property int minimumDeterministicPreviewSize: 48
    readonly property string browserSearchPlaceholder: appView.tagsVisible
                                                       ? (appView.tagsFilterActive ? i18n("Search pictures") : i18n("Search tags"))
                                                       : (appView.collectionsVisible
                                                          ? (appView.collectionsFolderActive ? i18n("Search pictures") : i18n("Search collections"))
                                                          : i18n("Search pictures"))
    readonly property bool footerControlsVisible: verticallyBiasedLayout
                                                  && !appView.editorVisible
                                                  && appView.viewerVisible

    Settings
    {
        id: browserSettings
        category: "Browser"
        property bool showLabels : false
        property bool fitPreviews : false
        property bool autoReload: true
        property string previewSizePreset : "medium"
        property string sortBy : "modified"
        property int sortOrder: Qt.DescendingOrder
        property bool gpsTags : false
        property string lastUsedTag
    }

    Settings
    {
        id: viewerSettings
        property bool tagBarVisible : true
        property bool previewBarVisible : false
        property bool enableOCR: Maui.Handy.isLinux
        property int ocrConfidenceThreshold: 40
        property int ocrBlockType : 0
        property int ocrSelectionType: 0
        property bool ocrPreprocessing : false
        property int ocrSegMode: IT.OCR.Auto

        property int slideshowInterval: 5  // seconds per image
        property bool slideshowLoop: true
    }

    Maui.InfoDialog
    {
        id: _confirmCloseDialog
        property bool prevent : true
        template.iconSource: "dialog-warning"
        message: i18n("There are multiple windows still open. Are you sure you want to close the application?")
        standardButtons: Dialog.Yes | Dialog.Cancel
        onAccepted:
        {
            prevent = false
            root.close()
        }
        onRejected:
        {
            prevent = true
            close()
        }
    }

    Component
    {
        id: _shortcutsDialogComponent
        ShortcutsDialog { onClosed: destroy() }
    }

    Component
    {
        id: _browserSearchFieldComponent

        Maui.SearchField
        {
            enabled: appView.browserSearchVisible
            implicitWidth: Math.min(320, Math.max(220, root.width * 0.24))
            placeholderText: browserSearchPlaceholder

            Component.onCompleted: text = root.browserSearchText

            onTextChanged:
            {
                if (root.browserSearchText !== text)
                    root.browserSearchText = text

                if (text.length === 0)
                    clearBrowserSearch()
                else
                    applyBrowserSearch(text)
            }

            onCleared:
            {
                root.browserSearchText = ""
                clearBrowserSearch()
            }

            Keys.priority: Keys.AfterItem
            Keys.onReturnPressed: event.accepted = true
            Keys.onEscapePressed:
            {
                root.resetToolbarSearch()
                root.browserSearchExpanded = false
            }
        }
    }

    Component
    {
        id: _commonOverflowMenuComponent

        Maui.ToolButtonMenu
        {
            icon.name: "overflow-menu"

            MenuItem
            {
                text: i18n("Shortcuts")
                icon.name: "configure-shortcuts"
                onTriggered: openShortcutsDialog()
            }

            MenuItem
            {
                text: i18n("Preferences")
                icon.name: "settings-configure"
                onTriggered: openSettingsDialog()
            }

            MenuItem
            {
                text: i18n("About")
                icon.name: "documentinfo"
                onTriggered: Maui.App.aboutDialog()
            }
        }
    }

    Component
    {
        id: _browserSortOverflowMenuComponent

        Maui.ToolButtonMenu
        {
            icon.name: "overflow-menu"

            Menu
            {
                title: i18n("Sort")
                icon.name: "view-sort"
                Maui.Controls.component: Component
                {
                    Item
                    {
                        implicitWidth: 0
                        implicitHeight: 0
                        visible: false
                    }
                }

                MenuItem
                {
                    text: i18n("Title")
                    checked: browserSettings.sortBy === "title"
                    checkable: true
                    autoExclusive: true
                    onTriggered: browserSettings.sortBy = "title"
                }

                MenuItem
                {
                    text: i18n("Modified")
                    checked: browserSettings.sortBy === "modified"
                    checkable: true
                    autoExclusive: true
                    onTriggered: browserSettings.sortBy = "modified"
                }

                MenuItem
                {
                    text: i18n("Size")
                    checked: browserSettings.sortBy === "size"
                    checkable: true
                    autoExclusive: true
                    onTriggered: browserSettings.sortBy = "size"
                }

                MenuItem
                {
                    text: i18n("Date")
                    checked: browserSettings.sortBy === "date"
                    checkable: true
                    autoExclusive: true
                    onTriggered: browserSettings.sortBy = "date"
                }

                MenuSeparator {}

                MenuItem
                {
                    text: i18n("Ascending")
                    icon.name: "view-sort-ascending"
                    checked: browserSettings.sortOrder === Qt.AscendingOrder
                    checkable: true
                    autoExclusive: true
                    onTriggered: browserSettings.sortOrder = Qt.AscendingOrder
                }

                MenuItem
                {
                    text: i18n("Descending")
                    icon.name: "view-sort-descending"
                    checked: browserSettings.sortOrder === Qt.DescendingOrder
                    checkable: true
                    autoExclusive: true
                    onTriggered: browserSettings.sortOrder = Qt.DescendingOrder
                }
            }

            MenuSeparator {}

            MenuItem
            {
                text: i18n("Shortcuts")
                icon.name: "configure-shortcuts"
                onTriggered: openShortcutsDialog()
            }

            MenuItem
            {
                text: i18n("Preferences")
                icon.name: "settings-configure"
                onTriggered: openSettingsDialog()
            }

            MenuItem
            {
                text: i18n("About")
                icon.name: "documentinfo"
                onTriggered: Maui.App.aboutDialog()
            }
        }
    }

    Component
    {
        id: _tagsSortOverflowMenuComponent

        Maui.ToolButtonMenu
        {
            icon.name: "overflow-menu"

            Menu
            {
                title: i18n("Sort")
                icon.name: "view-sort"
                Maui.Controls.component: Component
                {
                    Item
                    {
                        implicitWidth: 0
                        implicitHeight: 0
                        visible: false
                    }
                }

                MenuItem
                {
                    text: i18n("Name (A-Z)")
                    checked: currentBrowserSortIndex() === 0
                    checkable: true
                    autoExclusive: true
                    onTriggered: applyBrowserSort(0)
                }

                MenuItem
                {
                    text: i18n("Name (Z-A)")
                    checked: currentBrowserSortIndex() === 1
                    checkable: true
                    autoExclusive: true
                    onTriggered: applyBrowserSort(1)
                }

                MenuItem
                {
                    text: i18n("Date (newest)")
                    checked: currentBrowserSortIndex() === 2
                    checkable: true
                    autoExclusive: true
                    onTriggered: applyBrowserSort(2)
                }

                MenuItem
                {
                    text: i18n("Date (oldest)")
                    checked: currentBrowserSortIndex() === 3
                    checkable: true
                    autoExclusive: true
                    onTriggered: applyBrowserSort(3)
                }
            }

            MenuSeparator {}

            MenuItem
            {
                text: i18n("Shortcuts")
                icon.name: "configure-shortcuts"
                onTriggered: openShortcutsDialog()
            }

            MenuItem
            {
                text: i18n("Preferences")
                icon.name: "settings-configure"
                onTriggered: openSettingsDialog()
            }

            MenuItem
            {
                text: i18n("About")
                icon.name: "documentinfo"
                onTriggered: Maui.App.aboutDialog()
            }
        }
    }

    onClosing: (close) =>
               {
                   if(Maui.App.windowsOpened() > 1 && _confirmCloseDialog.prevent)
                   {
                       _confirmCloseDialog.open()
                       close.accepted = false
                       return
                   }
                   close.accepted = true
               }

    Maui.WindowBlur
    {
        view: root
        geometry: Qt.rect(0, 0, root.width, root.height)
        windowRadius: Maui.Style.radiusV
        enabled: true
    }

    Rectangle
    {
        anchors.fill: parent
        color: Maui.Theme.backgroundColor
        opacity: 0.76
        radius: Maui.Style.radiusV
        border.color: Qt.rgba(1, 1, 1, 0)
        border.width: 1
    }

    Maui.Page
    {
        id: _shellPage
        anchors.fill: parent
        background: null
        headBar.visible: !appView.editorVisible
        headBar.forceCenterMiddleContent: false
        altHeader: appView.viewerVisible && Maui.Handy.isMobile
        floatingHeader: appView.viewerVisible
        autoHideHeader: appView.viewerVisible && appView.pixViewer.viewer.imageZooming
        headerMargins: Maui.Style.contentMargins
        footerMargins: Maui.Style.contentMargins

        Shortcut
        {
            sequence: "Ctrl+,"
            onActivated: openSettingsDialog()
        }

        Shortcut
        {
            sequence: "Ctrl+/"
            onActivated: openShortcutsDialog()
        }

        Shortcut
        {
            sequence: "Ctrl+Home"
            onActivated: showGallery()
        }

        Shortcut
        {
            sequence: "Space"
            enabled: appView.activePixGridItemUrl.length > 0
            onActivated: getFileInfo(appView.activePixGridItemUrl)
        }

        Shortcut
        {
            sequence: "Ctrl+S"
            enabled: appView.viewerVisible && appView.pixViewer.currentPicUrl.length > 0
            onActivated: saveAs([appView.pixViewer.currentPicUrl])
        }

        Shortcut
        {
            sequence: "Ctrl+S"
            enabled: !appView.viewerVisible && appView.activePixGridItemUrl.length > 0
            onActivated: appView.selectCurrentGridItem()
        }

        Shortcut
        {
            sequence: "Ctrl+F"
            enabled: appView.viewerVisible
            onActivated: root.fullScreen ? root.showNormal() : root.showFullScreen()
        }

        Shortcut
        {
            sequence: "S"
            enabled: appView.viewerVisible
            onActivated: appView.pixViewer.slideshowActive = !appView.pixViewer.slideshowActive
        }

        Shortcut
        {
            sequence: "Ctrl+="
            enabled: !appView.viewerVisible && !appView.editorVisible
            onActivated: setNextPreviewSize()
        }

        Shortcut
        {
            sequence: "Ctrl+-"
            enabled: !appView.viewerVisible && !appView.editorVisible
            onActivated: setPreviousPreviewSize()
        }

        headBar.leftContent: [
            ToolButton
            {
                visible: appView.shellBackVisible
                icon.name: "go-previous"
                onClicked: handleToolbarBack()
            },

            ToolSeparator
            {
                visible: appView.shellBackVisible
                bottomPadding: 10
                topPadding: 10
            },

            ToolButton
            {
                icon.name: "view-preview"
                onClicked: showGallery()
            },

            ToolButton
            {
                icon.name: "folder"
                onClicked: showCollections()
            },

            ToolButton
            {
                icon.name: "tag"
                onClicked: showTags()
            },

            ToolButton
            {
                visible: appView.viewerVisible && !root.verticallyBiasedLayout
                icon.name: "view-fullscreen"
                checked: root.fullScreen
                onClicked: root.fullScreen ? root.showNormal() : root.showFullScreen()
            },

            ToolButton
            {
                visible: appView.viewerVisible && !root.verticallyBiasedLayout
                icon.name: "draw-freehand"
                onClicked: appView.openEditor(appView.pixViewer.currentPicUrl, appView.stackView)
            }
        ]

        headBar.rightContent: [
            ToolButton
            {
                visible: appView.viewerVisible && !root.verticallyBiasedLayout && appView.pixViewer.slideshowActive
                icon.name: "media-playback-stop"
                onClicked: appView.pixViewer.slideshowActive = false
            },

            ToolButton
            {
                visible: !appView.viewerVisible && !appView.editorVisible && appView.currentSlideshowModel
                icon.name: "media-playback-start"
                onClicked: startSlideshowForCurrentRoute()
            },

            ToolButton
            {
                visible: appView.viewerVisible && !root.verticallyBiasedLayout
                icon.name: "documentinfo"
                onClicked: getFileInfo(appView.pixViewer.currentPicUrl)
            },

            ToolButton
            {
                visible: appView.viewerVisible && !root.verticallyBiasedLayout
                icon.name: "edit-delete"
                onClicked: removeFiles([appView.pixViewer.currentPicUrl])
            },

            ToolButton
            {
                visible: appView.browserSearchVisible
                icon.name: "edit-find"
                checkable: true
                checked: root.browserSearchExpanded
                onClicked: toggleBrowserSearch()
            },

            ToolSeparator
            {
                visible: appView.viewerVisible || appView.browserSearchVisible || appView.browserSortVisible
                bottomPadding: 10
                topPadding: 10
            },

            Loader
            {
                active: true
                sourceComponent: appView.browserSortVisible
                                 ? (appView.tagsGridActive
                                    ? _tagsSortOverflowMenuComponent
                                    : _browserSortOverflowMenuComponent)
                                 : _commonOverflowMenuComponent
            }
        ]

        footBar.visible: footerControlsVisible
        footBar.forceCenterMiddleContent: false

        footBar.leftContent: [
            ToolButton
            {
                visible: root.verticallyBiasedLayout && appView.viewerVisible
                icon.name: "view-fullscreen"
                checked: root.fullScreen
                onClicked: root.fullScreen ? root.showNormal() : root.showFullScreen()
            },

            ToolButton
            {
                visible: root.verticallyBiasedLayout && appView.viewerVisible
                icon.name: "draw-freehand"
                onClicked: appView.openEditor(appView.pixViewer.currentPicUrl, appView.stackView)
            }
        ]

        footBar.middleContent: [
            Item {}
        ]

        footBar.rightContent: [
            ToolButton
            {
                visible: root.verticallyBiasedLayout && appView.viewerVisible && appView.pixViewer.slideshowActive
                icon.name: "media-playback-stop"
                onClicked: appView.pixViewer.slideshowActive = false
            },

            ToolButton
            {
                visible: root.verticallyBiasedLayout && appView.viewerVisible
                icon.name: "documentinfo"
                onClicked: getFileInfo(appView.pixViewer.currentPicUrl)
            },

            ToolButton
            {
                visible: root.verticallyBiasedLayout && appView.viewerVisible
                icon.name: "edit-delete"
                onClicked: removeFiles([appView.pixViewer.currentPicUrl])
            }
        ]

        Item
        {
            id: _browserSearchBar
            visible: appView.browserSearchVisible && root.browserSearchExpanded
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: visible ? (_browserSearchBarLayout.implicitHeight + (Maui.Style.contentMargins * 2)) : 0

            Rectangle
            {
                anchors.fill: parent
                color: Maui.Theme.backgroundColor
                border.color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
            }

            Item
            {
                id: _browserSearchBarLayout
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                implicitHeight: _topSearchFieldLoader.implicitHeight

                Loader
                {
                    id: _topSearchFieldLoader
                    anchors.centerIn: parent
                    active: _browserSearchBar.visible
                    visible: active
                    sourceComponent: _browserSearchFieldComponent
                }
            }
        }

        AppView
        {
            id: appView
            anchors.top: _browserSearchBar.visible ? _browserSearchBar.bottom : parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
    }

    SelectionBar
    {
        id: _selectionBar
        enabled: !appView.viewerVisible
        opacity: appView.viewerVisible ? 0 : 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: _shellPage.footBar.visible ? _shellPage.footer.height + Maui.Style.space.medium : 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width-(Maui.Style.space.medium*2), implicitWidth)
        maxListHeight: root.height - Maui.Style.space.medium
        display: ToolButton.IconOnly
    }

    Component
    {
        id: fmDialogComponent
        FB.FileDialog
        {
            mode: FB.FileDialog.Open
            onClosed: destroy()
        }
    }

    Connections
    {
        target: Pix.Collection

        function onViewPics(pics)
        {
            appView.openExternalPics(pics, 0)
        }
    }

    Connections
    {
        target: appView.stackView

        function onCurrentItemChanged()
        {
            resetToolbarSearch()
            browserSearchExpanded = false
        }
    }

    Connections
    {
        target: appView.currentRoute
        ignoreUnknownSignals: true

        function onBrowsingFolderChanged()
        {
            resetToolbarSearch()
            browserSearchExpanded = false
        }

        function onFilteringTagChanged()
        {
            resetToolbarSearch()
            browserSearchExpanded = false
        }
    }

    function fav(urls)
    {
        for(const i in urls)
            FB.Tagging.toggleFav(urls[i])
    }

    function view(urls : var, windowed : bool)
    {
        appView.openExternalPics(urls, 0)
    }

    function selectItem(item)
    {
        if(selectionBox.contains(item.url))
        {
            selectionBox.removeAtUri(item.url)
            return
        }
        selectionBox.append(item.url, item)
    }

    function filterSelection(url)
    {
        if(!selectionBox)
            return [url]

        if(selectionBox.contains(url))
        {
            return selectionBox.uris
        }else
        {
            return [url]
        }
    }

    function previewSizeForPreset(preset)
    {
        return previewSizes[preset] ?? previewSizes.medium
    }

    function effectivePreviewSize(preset)
    {
        const dpr = Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
        return Math.max(minimumDeterministicPreviewSize, Math.round(previewSizeForPreset(preset) / dpr))
    }

    function setPreviewSize(preset) { browserSettings.previewSizePreset = preset }
    function setNextPreviewSize()
    {
        switch (browserSettings.previewSizePreset)
        {
        case "small":
            setPreviewSize("medium")
            return
        case "medium":
            setPreviewSize("large")
            return
        case "large":
            setPreviewSize("extralarge")
            return
        default:
            setPreviewSize("extralarge")
            return
        }
    }

    function setPreviousPreviewSize()
    {
        switch (browserSettings.previewSizePreset)
        {
        case "extralarge":
            setPreviewSize("large")
            return
        case "large":
            setPreviewSize("medium")
            return
        case "medium":
            setPreviewSize("small")
            return
        default:
            setPreviewSize("small")
            return
        }
    }
    function applyBrowserSearch(text)
    {
        if (appView.browserSearchVisible && appView.currentRoute && appView.currentRoute.search)
            appView.currentRoute.search(text)
    }

    function clearBrowserSearch()
    {
        if (appView.browserSearchVisible && appView.currentRoute && appView.currentRoute.clearSearch)
            appView.currentRoute.clearSearch()
    }

    function applyBrowserSort(index)
    {
        if (appView.tagsGridActive
                && appView.currentRoute
                && typeof appView.currentRoute.applySort === "function")
            appView.currentRoute.applySort(index)
    }

    function currentBrowserSortIndex()
    {
        if (appView.tagsGridActive
                && appView.currentRoute
                && typeof appView.currentRoute.currentSortIndex === "function")
            return appView.currentRoute.currentSortIndex()

        return -1
    }

    function focusBrowserSearchField()
    {
        if (_topSearchFieldLoader.item)
            _topSearchFieldLoader.item.forceActiveFocus()
    }

    function toggleBrowserSearch()
    {
        if (!appView.browserSearchVisible)
            return

        browserSearchExpanded = !browserSearchExpanded

        if (browserSearchExpanded)
            Qt.callLater(focusBrowserSearchField)
        else
            resetToolbarSearch()
    }

    function resetToolbarSearch()
    {
        browserSearchText = ""

        if (_topSearchFieldLoader.item)
            _topSearchFieldLoader.item.text = ""

        clearBrowserSearch()
    }
    function handleToolbarBack()
    {
        if (appView.viewerVisible) {
            appView.toggleViewer()
            return
        }

        if (appView.currentRoute && appView.currentRoute.goBack) {
            resetToolbarSearch()
            appView.currentRoute.goBack()
            if (appView.currentRoute && appView.currentRoute.forceActiveFocus)
                appView.currentRoute.forceActiveFocus()
        }
    }
    function startSlideshowForCurrentRoute()
    {
        if (appView.currentSlideshowModel)
            appView.startSlideshowFromModel(appView.currentSlideshowModel)
    }
    function getFileInfo(url) { appView.getFileInfo(url) }
    function removeFiles(urls) { appView.removeFiles(urls) }
    function saveAs(urls) { appView.saveAs(urls) }
    function openFileWith(urls) { appView.openFileWith(urls) }
    function openTagsDialog(urls) { appView.openTagsDialog(urls) }
    function openEditor(url, stack) { appView.openEditor(url, stack) }
    function openFileDialog() { appView.openFileDialog() }
    function openSettingsDialog() { appView.openSettingsDialog() }
    function openShortcutsDialog()
    {
        var dialog = _shortcutsDialogComponent.createObject(root)
        dialog.open()
    }
    function openFolder(url, filters) { appView.openFolder(url, filters) }
    function toggleViewer() { resetToolbarSearch(); appView.toggleViewer() }
    function toogleTagbar() { appView.toogleTagbar() }
    function tooglePreviewBar() { appView.tooglePreviewBar() }
    function showGallery() { resetToolbarSearch(); appView.showGallery() }
    function showCollections() { resetToolbarSearch(); appView.showCollections() }
    function showTags() { resetToolbarSearch(); appView.showTags() }
    function startSlideshow() { appView.startSlideshow() }
    function startSlideshowFromModel(galleryList) { appView.startSlideshowFromModel(galleryList) }
}
