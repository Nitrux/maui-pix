// Copyright 2018-2020 Camilo Higuita <milo.h@aol.com>
// Copyright 2018-2020 Nitrux Latinoamericana S.C.
//
// SPDX-License-Identifier: GPL-3.0-or-later


import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.mauikit.controls as Maui

import "../widgets/views/Viewer/Viewer.js" as VIEWER

Maui.SelectionBar
{
    id: control

    onExitClicked:
    {
        root.selectionMode = false
        clear()
    }

    listDelegate: Maui.ListBrowserDelegate
    {
        width: ListView.view.width
        isCurrentItem: false

        label1.text: model.title
        label2.text: model.url
        imageSource: model.url
        iconSizeHint: Maui.Style.iconSizes.big
        height: Maui.Style.iconSizes.big + Maui.Style.space.big
        checked: true
        checkable: true

        onToggled: control.removeAtIndex(index)

        background: Item {}
    }

    Action
    {
        text: i18n("View")
        icon.name: "document-preview-archive"
        onTriggered: VIEWER.openExternalPics(control.uris, 0)
    }


    Action
    {
        text: i18n("Tag")
        icon.name: "tag"
        onTriggered:
        {
            openTagsDialog(control.uris)
        }
    }

}

