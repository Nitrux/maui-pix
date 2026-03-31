// Copyright 2018-2020 Camilo Higuita <milo.h@aol.com>
// Copyright 2018-2020 Nitrux Latinoamericana S.C.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import QtQuick.Controls
import QtQuick.Layouts

import org.mauikit.controls as Maui
import org.maui.pix as Pix

import "../../../view_models"

PixGrid
{
    id: control
    list: Pix.Collection.allImagesModel
    background: null
    Maui.Controls.showCSD: true
    headerMargins: Maui.Style.contentMargins

    holder.emoji: "image-x-generic"
    holder.title : i18n("No Pics!")
    holder.body: list.status === Pix.GalleryList.Error ? list.error : i18n("Nothing here. You can add new sources or open an image.")

    headBar.leftContent: [
        ToolButton
        {
            icon.name: "view-preview"
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
            placeholderText: i18n("Search pictures")
            implicitWidth: 250
            onAccepted: control.search(text)
            onCleared: control.clearSearch()
        }
    ]

    headBar.rightContent: [
        Loader
        {
            sourceComponent: control.extraOptions
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
