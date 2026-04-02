// Copyright 2018-2020 Camilo Higuita <milo.h@aol.com>
// Copyright 2018-2020 Nitrux Latinoamericana S.C.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.mauikit.controls as Maui
import org.maui.pix as Pix

import "../../../view_models"

StackView
{
    id: control
    background: null

    readonly property Flickable flickable : currentItem.flickable

    initialItem: _frontPageComponent

    Component
    {
        id: tagsGrid

        TagsView
        {
            id: _tagGridView
            background: null
            list.urls: ["tags:///" + currentTag]
            list.recursive: false

            Maui.Controls.showCSD: true
            headerMargins: Maui.Style.contentMargins
            headBar.visible: true

            headBar.leftContent: [
                ToolButton
                {
                    icon.name: "go-previous"
                    onClicked: control.pop()
                },

                ToolSeparator {
                    bottomPadding: 10
                    topPadding: 10
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

                ToolButton
                {
                    icon.name: "tag"
                    onClicked: ApplicationWindow.window.showTags()
                },

                ToolSeparator {
                    bottomPadding: 10
                    topPadding: 10
                },

                Maui.SearchField
                {
                    enabled: _tagGridView.list.count > 0
                    placeholderText: i18np("Search image", "Search %1 images", _tagGridView.list.count)
                    implicitWidth: 250
                    onTextChanged: _tagGridView.search(text)
                    onCleared: _tagGridView.clearSearch()
                    Keys.priority: Keys.AfterItem
                    Keys.onReturnPressed: event.accepted = true
                }
            ]

            headBar.rightContent: [
                ToolButton
                {
                    icon.name: "media-playback-start"
                    onClicked: ApplicationWindow.window.startSlideshowFromModel(_tagGridView.list)
                },

                Loader
                {
                    sourceComponent: _tagGridView.extraOptions
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
        }
    }

Component
    {
        id: _frontPageComponent

        Maui.Page
        {
            id: _frontPage
            background: null

            Maui.Theme.inherit: false
            Maui.Theme.colorGroup: Maui.Theme.View

            Maui.Controls.showCSD: true
            headerMargins: Maui.Style.contentMargins

            flickable: _gridView.flickable

            headBar.visible: true
            headBar.forceCenterMiddleContent: false

            headBar.leftContent: [
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

                ToolButton
                {
                    icon.name: "tag"
                    onClicked: ApplicationWindow.window.showTags()
                },

                ToolSeparator {
                    bottomPadding: 10
                    topPadding: 10
                },

                Label
                {
                    text: i18n("Sort")
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                },

                ComboBox
                {
                    id: _sortComboBox
                    implicitWidth: 180
                    currentIndex: 0

                    model: [
                        i18n("Name (A-Z)"),
                        i18n("Name (Z-A)"),
                        i18n("Date (newest)"),
                        i18n("Date (oldest)")
                    ]

                    readonly property var _sorts: [
                        { sort: "tag",     order: Qt.AscendingOrder  },
                        { sort: "tag",     order: Qt.DescendingOrder },
                        { sort: "adddate", order: Qt.DescendingOrder },
                        { sort: "adddate", order: Qt.AscendingOrder  }
                    ]

                    onActivated: (index) =>
                    {
                        _tagsModel.sort = _sorts[index].sort
                        _tagsModel.sortOrder = _sorts[index].order
                    }
                }
            ]

            headBar.rightContent: [
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

            Maui.GridBrowser
            {
                id: _gridView
                anchors.fill: parent
                model: Maui.BaseModel
                {
                    id: _tagsModel
                    recursiveFilteringEnabled: true
                    sortCaseSensitivity: Qt.CaseInsensitive
                    filterCaseSensitivity: Qt.CaseInsensitive
                    sort: "tag"
                    sortOrder: Qt.AscendingOrder

                    list: Pix.TagsList
                    {
                        id: _tagsList
                    }
                }

                Keys.onPressed: (event) =>
                {
                    if(event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    {
                        populateGrid(_gridView.currentItem.tag)
                        event.accepted = true
                    }
                }

                itemSize: Math.min(260, Math.max(100, Math.floor(width * 0.3)))
                itemHeight: itemSize + Maui.Style.rowHeight
                currentIndex: -1

                holder.visible: _gridView.count === 0
                holder.emoji: "tag"
                holder.title: i18n("No Tags!")
                holder.body: i18n("You can create new tags to organize your gallery")

                delegate: Item
                {
                    height: GridView.view.cellHeight
                    width: GridView.view.cellWidth
                    readonly property string tag : model.tag

                    Maui.GalleryRollItem
                    {
                        anchors.fill: parent
                        anchors.margins: !root.isWide ? Maui.Style.space.tiny : Maui.Style.space.big

                        imageWidth: 120
                        imageHeight: 120

                        isCurrentItem: parent.GridView.isCurrentItem
                        images: model.preview.split(",")

                        label1.text: model.tag
                        label2.text: Qt.formatDateTime(new Date(model.adddate), "d MMM yyyy")

                        onClicked:
                        {
                            _gridView.currentIndex = index
                            if(Maui.Handy.singleClick)
                            {
                                populateGrid(model.tag)
                            }
                        }

                        onDoubleClicked:
                        {
                            _gridView.currentIndex = index
                            if(!Maui.Handy.singleClick)
                            {
                                populateGrid(model.tag)
                            }
                        }
                    }
                }
            }
        }
    }

    function refreshPics()
    {
        tagsGrid.list.refresh()
    }

    function populateGrid(myTag)
    {
        control.push(tagsGrid, {'currentTag': myTag})
    }

}

