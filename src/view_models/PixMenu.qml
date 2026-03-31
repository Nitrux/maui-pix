import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.mauikit.controls as Maui
import org.mauikit.filebrowsing as FB

import org.maui.pix as Pix

Maui.ContextualMenu
{
    id: control

    property int index : -1
    property Maui.BaseModel model : null
    property var item : ({})
    readonly property string totalCount : filterSelection(item.url).length > 1 ? filterSelection(item.url).length : ""

    property alias editMenuItem : _editMenuItem

    onOpened:
    {
        if(control.model && control.index >= 0)
        {
            control.item = control.model.get(control.index)
        }
    }

    MenuItem
    {
        enabled: typeof selectionBox !== "undefined"
        visible: enabled
        height: visible ? implicitHeight : -control.spacing
        text: i18n("Select")
        icon.name: "item-select"
        onTriggered:
        {
            if(Maui.Handy.isTouch)
                root.selectionMode = true

            selectItem(item)
        }
    }

    MenuSeparator{}

    MenuItem
    {
        visible: browserSettings.lastUsedTag.length > 0
        height: visible ? implicitHeight : -control.spacing
        text: i18n("Add to '%1'", browserSettings.lastUsedTag)
        icon.name: "tag"
        onTriggered:
        {
            FB.Tagging.tagUrl(control.item.url, browserSettings.lastUsedTag)
        }
    }

    MenuSeparator{}

    MenuItem
    {
        id: _editMenuItem
        text: i18n("Edit")
        icon.name: "document-edit"
        onTriggered:
        {
            if(action)
                return
            openEditor(item.url, _stackView)
        }
    }

    MenuItem
    {
        text: i18n("Go to Folder")
        icon.name: "folder-open"
        onTriggered:
        {
            if(pixViewer.active)
            {
                toggleViewer()
            }

            var url = FB.FM.fileDir(item.url)
            openFolder(url)
        }
    }

    MenuItem
    {
        text: i18n("Copy Path to Clipboard")
        icon.name: "edit-copy"
        onTriggered: Maui.Handy.copyTextToClipboard(item.url.replace("file://", ""))
    }

    MenuSeparator{}

    MenuItem
    {
        text: i18n("Remove")
        icon.name: "edit-delete"
        Maui.Controls.badgeText: control.totalCount
        Maui.Controls.status: Maui.Controls.Negative
        onTriggered: removeFiles(filterSelection(item.url))
    }
}
