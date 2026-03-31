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
import QtQuick.Controls

import org.mauikit.controls as Maui
import org.maui.pix as Pix

import "Folders"

Maui.Page
{
    id: control
    objectName: "CollectionView"

    background: null
    Maui.Controls.showCSD: true

    focus: true
    focusPolicy: Qt.StrongFocus

    Keys.enabled: true
    Keys.forwardTo: _foldersView

    readonly property var mainGalleryList : Pix.Collection.allImagesModel
    property alias currentFolder :_foldersView.currentFolder

    Binding
    {
        target: Pix.Collection.allImagesModel
        property: "autoReload"
        value: browserSettings.autoReload
        delayed: true
    }

    Binding
    {
        target: Pix.Collection.allImagesModel
        property: "activeGeolocationTags"
        value: browserSettings.gpsTags
        delayed: true
    }

    readonly property Component extraOptions: (_foldersView.currentItem && _foldersView.currentItem.hasOwnProperty("extraOptions"))
                                              ? _foldersView.currentItem.extraOptions
                                              : null

    headBar.leftContent: [
        ToolButton
        {
            enabled: _foldersView.depth > 1
            icon.name: "go-previous"
            onClicked: _foldersView.pop()
        },

        ToolButton
        {
            icon.name: "folder-pictures"
            onClicked: ApplicationWindow.window.showGallery()
        },

        ToolButton
        {
            icon.name: "folder"
            onClicked: ApplicationWindow.window.showCollections()
        },

        ToolSeparator {},

        Maui.SearchField
        {
            placeholderText: i18n("Search pictures")
            implicitWidth: 250
            onAccepted: _foldersView.search(text)
            onCleared: _foldersView.clearSearch()
        }
    ]

    headBar.rightContent: [
        Loader
        {
            active: control.extraOptions !== null
            sourceComponent: control.extraOptions
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

    Item
    {
        id: _contentArea
        anchors.fill: parent

        Binding
        {
            when: selectionBox.visible
            target: _foldersView.flickable
            property: "bottomMargin"
            value: selectionBox.implicitHeight
            restoreMode: Binding.RestoreBindingOrValue
        }

        FoldersView
        {
            id: _foldersView
            anchors.fill: parent
        }

        FloatingViewer
        {
            id: _floatingViewer

            DragHandler
            {
                target: _floatingViewer
                xAxis.maximum: _contentArea.width - _floatingViewer.width
                xAxis.minimum: 0

                yAxis.maximum: _contentArea.height - _floatingViewer.height
                yAxis.minimum: 0

                onActiveChanged:
                {
                    if(!active)
                    {
                        let newX = Math.abs(_floatingViewer.x - (_contentArea.width - _floatingViewer.implicitWidth - 20))
                        _floatingViewer.y = Qt.binding(()=> { return _floatingViewer.parent.height - _floatingViewer.implicitHeight - 20})
                        _floatingViewer.x = Qt.binding(()=> { return (_floatingViewer.parent.width - _floatingViewer.implicitWidth - 20 - newX) < 0 ? 20 : _contentArea.width - _floatingViewer.implicitWidth - 20 - newX})
                    }
                }
            }
        }
    }

    function openFolder(url, filters)
    {
        _foldersView.openFolder(url, filters)
    }

    function goBack()
    {
        _foldersView.pop()
    }

    function search(text)
    {
        _foldersView.search(text)
    }

    function clearSearch()
    {
        _foldersView.clearSearch()
    }
}
