pragma ComponentBehavior: Unbound

import QtQuick
import QtQuick.Controls

import "views"
import "views/Viewer"
import "views/Gallery"
import "views/Tags"

import org.mauikit.controls as Maui
import org.mauikit.filebrowsing as FB
import org.mauikit.imagetools as IT
import org.maui.pix as Pix
import org.mauikit.imagetools.editor as ITEditor

Item
{
    id: control
    Keys.enabled: true
    Keys.forwardTo: _stackView

    property QtObject tagsDialog : null

    readonly property alias pixViewer : _pixViewer
    readonly property alias viewer : _pixViewer.viewer
    readonly property alias stackView : _stackView
    readonly property alias collectionViewComponent : _collectionViewComponent

    readonly property bool editorVisible : _stackView.currentItem.objectName === "ImageEditor"
    readonly property bool viewerVisible : _stackView.currentItem.objectName === "Viewer"
    readonly property var mainGalleryList: Pix.Collection.allImagesModel

    Action
    {
        id: _openSettingsAction
        text: i18n("Settings")
        icon.name: "settings-configure"
        onTriggered: openSettingsDialog()
    }

    Component
    {
        id: _galleryViewComponent
        GalleryView {}
    }

    StackView
    {
        id: _stackView
        anchors.fill: parent
        objectName: "MainView"
        background: null

        focus: false
        focusPolicy: Qt.NoFocus

        Keys.enabled: true
        Keys.forwardTo: [currentItem]
        Keys.onEscapePressed:
        {
            if(selectionBox.visible)
            {
                selectionBox.clear()
                return
            }
            _stackView.pop()
        }

        function forceActiveFocus()
        {
            _stackView.currentItem.forceActiveFocus()
        }

        initialItem: _galleryViewComponent

        PixViewer
        {
            id: _pixViewer
            objectName: "Viewer"
            readonly property bool active: StackView.status === StackView.Active
            background: null

            onCloseRequested: control.toggleViewer()
            onEditRequested: (url) => control.openEditor(url, _stackView)
        }
    }

    Component
    {
        id: _collectionViewComponent
        CollectionView {}
    }

    Component
    {
        id: _tagsViewComponent
        TagsSidebar { objectName: "TagsView" }
    }

    property int lastEditorAction : ITEditor.ImageEditor.ActionType.Colors
    Component
    {
        id: _editorComponent

        ITEditor.ImageEditor
        {
            id: _editor
            objectName: "ImageEditor"
            Maui.Controls.showCSD: true
            initialActionType: lastEditorAction
            headerMargins: Maui.Style.contentMargins

            headBar.farLeftContent: ToolButton
            {
                Maui.Controls.status: _editor.editor.edited ? Maui.Controls.Positive : Maui.Controls.Normal
                onClicked: _editor.editor.edited ? _editor.save() : _editor.canceled()
            }

            headBar.farRightContent: ToolButton
            {
                enabled: _editor.editor.edited
                Maui.Controls.status: Maui.Controls.Negative
                onClicked: _editor.cancel()
            }

            onSaved:
            {
                lastEditorAction = getCurrentActionType()
                _saveNotification.url = url
                _editor.StackView.view.pop()

                if(!control.viewerVisible)
                {
                    _saveNotification.dispatch()
                }
            }

            onCanceled:
            {
                lastEditorAction = getCurrentActionType()

                if(!editor.edited)
                {
                    _editor.StackView.view.pop()
                    return
                }
            }
        }
    }

    Maui.Notification
    {
        id: _saveNotification
        iconSource: url
        title: i18n("Saved")
        message: i18n("The image has been saved correctly.")
        property string url
        Action
        {
            text: i18n("View")
            onTriggered: openExternalPics([_saveNotification.url], 0)
        }
    }

    Loader
    {
        anchors.fill: parent
        visible: _dropAreaLoader.item.containsDrag
        asynchronous: true

        sourceComponent: Rectangle
        {
            color: Qt.rgba(Maui.Theme.backgroundColor.r, Maui.Theme.backgroundColor.g, Maui.Theme.backgroundColor.b, 0.95)

            Maui.Rectangle
            {
                anchors.fill: parent
                anchors.margins: Maui.Style.space.medium
                color: "transparent"
                borderColor: Maui.Theme.textColor
                solidBorder: false

                Maui.Holder
                {
                    anchors.fill: parent
                    visible: true
                    emoji: "folder-pictures"
                    emojiSize: Maui.Style.iconSizes.huge
                    title: i18n("Open images")
                    body: i18n("Drag and drop images here.")
                }
            }
        }
    }

    Loader
    {
        id: _dropAreaLoader
        anchors.fill: parent

        sourceComponent: DropArea
        {
            onDropped: (drop) =>
                       {
                if(drop.urls)
                {
                    openExternalPics(drop.urls, 0)
                }
            }

            onEntered: (drag) =>
                       {
                if(drag.source)
                {
                    return
                }

                if(!_pixViewer.active)
                {
                    _stackView.push(_pixViewer)
                }
            }
        }
    }

    Component
    {
        id: _infoDialogComponent
        IT.ImageInfoDialog
        {
            onGpsEdited:(url) => Pix.Collection.allImagesModel.updateGpsTag(url)
            onClosed: destroy()
        }
    }

    Component
    {
        id: tagsDialogComponent

        FB.TagsDialog
        {
            Maui.Notification
            {
                id: _taggedNotification
                iconName: "dialog-info"
                title: i18n("Tagged")
                message: i18n("File was tagged successfully")

                Action
                {
                    property string tag
                    id: _openTagAction
                    text: tag
                    enabled: tag.length > 0
                    onTriggered:
                    {
                        openFolder("tags:///"+tag)
                    }
                }
            }

            onTagsReady: (tags) =>
                         {
                if(tags.length === 1)
                {
                    _openTagAction.tag = tags[0]
                    _taggedNotification.dispatch()
                }
                browserSettings.lastUsedTag = tags[0]
                composerList.updateToUrls(tags)
            }

            composerList.strict: false
        }
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

    Component
    {
        id: _settingsDialogComponent
        SettingsDialog
        {
            onClosed:
            {
                destroy()
            }
        }
    }

    Component
    {
        id: _removeDialogComponent

        Maui.InfoDialog
        {
            property var urls: []

            title: i18np("Delete %1 file?", "Delete %1 files?", urls.length)
            message: i18np("Are you sure you want to delete this file? This action cannot be undone.", "Are you sure you want to delete these %1 files? This action cannot be undone.", urls.length)
            template.iconSource: "edit-delete"
            standardButtons: Dialog.Ok | Dialog.Cancel

            onAccepted:
            {
                Pix.Collection.allImagesModel.removeFiles(urls)
                selectionBox.clear()
            }

            onClosed: destroy()
        }
    }

    FB.OpenWithDialog
    {
        id: _openWithDialog
    }

    function setPreviewSize(size)
    {
        console.log(size)
        browserSettings.previewSize = size
    }

    function getFileInfo(url)
    {
        var dialog = _infoDialogComponent.createObject(control, ({'url': url}))
        dialog.open()
    }

    function toogleTagbar()
    {
        viewerSettings.tagBarVisible = !viewerSettings.tagBarVisible
    }

    function tooglePreviewBar()
    {
        viewerSettings.previewBarVisible = !viewerSettings.previewBarVisible
    }

    function toggleViewer()
    {
        if(_pixViewer.active)
        {
            _stackView.pop()
        }else
        {
            _stackView.push(_pixViewer)
        }

        _stackView.currentItem.forceActiveFocus()
    }

    function showGallery()
    {
        _stackView.pop(null)
        _stackView.currentItem.forceActiveFocus()
    }

    function showCollections()
    {
        if(_stackView.currentItem.objectName === "CollectionView")
            return

        if(_pixViewer.active)
            _stackView.pop()

        if(_stackView.currentItem.objectName !== "CollectionView")
            _stackView.push(_collectionViewComponent)

        _stackView.currentItem.forceActiveFocus()
    }

    function showTags()
    {
        if(_stackView.currentItem.objectName === "TagsView")
            return

        if(_pixViewer.active)
            _stackView.pop()

        if(_stackView.currentItem.objectName !== "TagsView")
            _stackView.push(_tagsViewComponent)

        _stackView.currentItem.forceActiveFocus()
    }

    function openFileDialog()
    {
        let props = ({ 'browser.settings.filterType' : FB.FMList.IMAGE,
                         'callback' : function(paths)
                         {
                             openExternalPics(paths)
                         }})
        var dialog = fmDialogComponent.createObject(control, props)
        dialog.open()
    }

    function openSettingsDialog()
    {
        var dialog = _settingsDialogComponent.createObject(control)
        dialog.open()
    }

    function openFolder(url : string, filters : var)
    {
        if(pixViewer.active)
        {
            _stackView.pop()
        }

        if(_stackView.currentItem.objectName !== "CollectionView")
        {
            _stackView.push(_collectionViewComponent)
        }

        _stackView.currentItem.openFolder(url, filters)
    }

    function openEditor(url, stack)
    {
        stack.push(_editorComponent, ({url: url}))
    }

    function openExternalPics(pics, index)
    {
        var oldIndex = pics.lenght-1
        pixViewer.viewer.clear()
        pixViewer.viewer.appendPics(pics)
        pixViewer.view(Math.max(oldIndex, index, 0))
        if(!pixViewer.active)
        {
            toggleViewer()
        }
    }

    function open(model, index, recursive = false)
    {
        pixViewer.model.list.recursive = model.list.recursive
        pixViewer.model.list.urls = model.list.urls

        pixViewer.view( pixViewer.model.mappedFromSource(index))
        if(!pixViewer.active)
        {
            toggleViewer()
        }
    }

    function openTagsDialog(urls)
    {
        if(control.tagsDialog)
        {
            control.tagsDialog.composerList.urls = urls
        }else
        {
            control.tagsDialog = tagsDialogComponent.createObject(control, ({'composerList.urls' : urls}))
        }

        control.tagsDialog.open()
    }

    function saveAs(urls)
    {
        let pic = urls[0]
        let props = ({'mode' : FB.FileDialog.Save,
                         'browser.settings.filterType' : FB.FMList.IMAGE,
                         'singleSelection' : true,
                         'suggestedFileName' : FB.FM.getFileInfo(pic).label,
                         'callback' : function(paths)
                         {
                             console.log("Sate to ", paths)
                             FB.FM.copy(urls, paths[0])

                         }})
        var dialog = fmDialogComponent.createObject(control, props)
        dialog.open()
    }

    function removeFiles(urls)
    {
        var dialog = _removeDialogComponent.createObject(control, ({'urls' : urls}))
        dialog.open()
    }

    function openFileWith(urls)
    {
        if(Maui.Handy.isAndroid)
        {
            FB.FM.openUrl(item.url)
            return
        }

        _openWithDialog.urls = urls
        _openWithDialog.open()
    }
}
