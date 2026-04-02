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
    readonly property var previewSizes: ({small: 72,
                                             medium: 90,
                                             large: 120,
                                             extralarge: 160})

    Settings
    {
        id: browserSettings
        category: "Browser"
        property bool showLabels : false
        property bool fitPreviews : false
        property bool autoReload: true
        property int previewSize : previewSizes.medium
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
        anchors.fill: parent
        background: null
        headBar.visible: false

        AppView
        {
            id: appView
            anchors.fill: parent
        }
    }

    SelectionBar
    {
        id: _selectionBar
        visible: !appView.viewerVisible
        anchors.bottom: parent.bottom
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

    function setPreviewSize(size) { browserSettings.previewSize = size }
    function getFileInfo(url) { appView.getFileInfo(url) }
    function removeFiles(urls) { appView.removeFiles(urls) }
    function saveAs(urls) { appView.saveAs(urls) }
    function openFileWith(urls) { appView.openFileWith(urls) }
    function openTagsDialog(urls) { appView.openTagsDialog(urls) }
    function openEditor(url, stack) { appView.openEditor(url, stack) }
    function openFileDialog() { appView.openFileDialog() }
    function openSettingsDialog() { appView.openSettingsDialog() }
    function openFolder(url, filters) { appView.openFolder(url, filters) }
    function toggleViewer() { appView.toggleViewer() }
    function toogleTagbar() { appView.toogleTagbar() }
    function tooglePreviewBar() { appView.tooglePreviewBar() }
    function showGallery() { appView.showGallery() }
    function showCollections() { appView.showCollections() }
    function showTags() { appView.showTags() }
    function startSlideshow() { appView.startSlideshow() }
    function startSlideshowFromModel(galleryList) { appView.startSlideshowFromModel(galleryList) }
}
