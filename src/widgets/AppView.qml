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
    readonly property alias currentRoute : _stackView.currentItem

    readonly property bool editorVisible : currentRoute && currentRoute.objectName === "ImageEditor"
    readonly property bool viewerVisible : currentRoute && currentRoute.objectName === "Viewer"
    readonly property bool galleryVisible : currentRoute && !viewerVisible && !editorVisible && currentRoute.objectName === "GalleryView"
    readonly property bool collectionsVisible : currentRoute && !viewerVisible && !editorVisible && currentRoute.objectName === "CollectionView"
    readonly property bool tagsVisible : currentRoute && !viewerVisible && !editorVisible && currentRoute.objectName === "TagsView"
    readonly property bool collectionsFolderActive : collectionsVisible && currentRoute && currentRoute.browsingFolder
    readonly property bool tagsFilterActive : tagsVisible && currentRoute && currentRoute.filteringTag
    readonly property bool tagsGridActive : tagsVisible && currentRoute && !currentRoute.filteringTag
    readonly property bool browserSearchVisible : galleryVisible || collectionsFolderActive || tagsGridActive
    readonly property bool browserSortVisible : galleryVisible || collectionsFolderActive || tagsVisible
    readonly property bool shellBackVisible : viewerVisible || collectionsFolderActive || tagsFilterActive
    readonly property var activePixGrid: galleryVisible
                                       ? currentRoute
                                       : (collectionsVisible && currentRoute
                                          ? currentRoute.activeGrid
                                          : (tagsVisible && currentRoute ? currentRoute.activeGrid : null))
    readonly property var activePixGridItem: activePixGrid && activePixGrid.currentIndex > -1 && activePixGrid.model
                                           ? activePixGrid.model.get(activePixGrid.currentIndex)
                                           : null
    readonly property string activePixGridItemUrl: activePixGridItem && activePixGridItem.url ? String(activePixGridItem.url) : ""
    readonly property Component currentExtraOptions: galleryVisible && currentRoute
                                                   ? currentRoute.extraOptions
                                                   : (collectionsVisible && currentRoute
                                                      ? currentRoute.extraOptions
                                                      : (tagsVisible && currentRoute ? currentRoute.currentExtraOptions : null))
    readonly property var currentSlideshowModel: galleryVisible
                                               ? mainGalleryList
                                               : (collectionsVisible && currentRoute
                                                  ? currentRoute.currentSlideshowModel
                                                  : (tagsVisible && currentRoute ? currentRoute.currentSlideshowModel : null))
    readonly property var mainGalleryList: Pix.Collection.allImagesModel

    Action
    {
        id: _openSettingsAction
        text: i18n("Settings")
        icon.name: "settings-configure"
        onTriggered: openSettingsDialog()
    }

    function selectCurrentGridItem()
    {
        if (activePixGridItem)
            selectItem(activePixGridItem)
    }

    Component
    {
        id: _galleryViewComponent
        GalleryView { useInternalChrome: false }
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
            if (_stackView.currentItem)
                _stackView.currentItem.forceActiveFocus()
        }

        initialItem: _galleryViewComponent

        PixViewer
        {
            id: _pixViewer
            objectName: "Viewer"
            useInternalChrome: false
            readonly property bool active: StackView.status === StackView.Active
            background: null

            onCloseRequested:
        {
            _pixViewer.slideshowActive = false
            control.toggleViewer()
        }
            onEditRequested: (url) => control.openEditor(url, _stackView)
        }
    }

    Component
    {
        id: _collectionViewComponent
        CollectionView { useInternalChrome: false }
    }

    Component
    {
        id: _tagsViewComponent
        TagsSidebar { objectName: "TagsView"; useInternalChrome: false }
    }

    property int lastEditorAction : ITEditor.ImageEditor.ActionType.Colors

    function refreshAfterEditorSave(savedUrl)
    {
        const cleanUrl = savedUrl && String(savedUrl).length > 0 ? String(savedUrl) : ""

        Pix.Collection.allImagesModel.rescan()

        Qt.callLater(() =>
        {
            if(cleanUrl.length > 0 && pixViewer.currentPicUrl === cleanUrl)
            {
                pixViewer.viewer.reloadCurrentItem()
            }

            if(currentRoute && currentRoute.activeGrid && currentRoute.activeGrid.list && currentRoute.activeGrid.list.refresh)
            {
                currentRoute.activeGrid.list.refresh()
            }

            if(currentRoute && currentRoute.refreshPics)
            {
                currentRoute.refreshPics()
            }
        })
    }

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

            onSaved:
            {
                lastEditorAction = getCurrentActionType()
                _saveNotification.url = url
                _editor.StackView.view.pop()
                refreshAfterEditorSave(url)

                if(!control.viewerVisible)
                {
                    _saveNotification.dispatch()
                }
            }

            onSaveAsRequested:
            {
                lastEditorAction = getCurrentActionType()

                const sourceUrl = String(url)
                const props = ({'mode' : FB.FileDialog.Save,
                                   'browser.settings.filterType' : FB.FMList.IMAGE,
                                   'singleSelection' : true,
                                   'suggestedFileName' : FB.FM.getFileInfo(sourceUrl).label,
                                   'callback' : function(paths)
                                   {
                                       if(!paths || paths.length === 0)
                                           return

                                       const targetUrl = paths[0]
                                       if(_editor.editor.saveAs(targetUrl))
                                       {
                                           _saveNotification.url = targetUrl
                                           _editor.StackView.view.pop()
                                           refreshAfterEditorSave(sourceUrl)

                                           if(!control.viewerVisible)
                                           {
                                               _saveNotification.dispatch()
                                           }
                                       }
                                   }})

                var dialog = fmDialogComponent.createObject(control, props)
                dialog.open()
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
                if (_pixViewer.active)
                    _pixViewer.removeUrls(urls)
                selectionBox.clear()
            }

            onClosed: destroy()
        }
    }

    FB.OpenWithDialog
    {
        id: _openWithDialog
    }

    function setPreviewSize(preset)
    {
        console.log(preset)
        browserSettings.previewSizePreset = preset
    }

    function getFileInfo(url)
    {
        if (!url || String(url).length === 0)
            return

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

        if (_stackView.currentItem)
            _stackView.currentItem.forceActiveFocus()
    }

    function startSlideshow()
    {
        _pixViewer.sourceModel = null
        _pixViewer.model.list.recursive = mainGalleryList.recursive
        _pixViewer.model.list.urls = mainGalleryList.urls
        _pixViewer.view(0)
        if (!_pixViewer.active)
            toggleViewer()
        _pixViewer.slideshowActive = true
    }

    function startSlideshowFromModel(galleryList)
    {
        _pixViewer.sourceModel = null
        _pixViewer.model.list.recursive = galleryList.recursive
        _pixViewer.model.list.urls = galleryList.urls
        _pixViewer.view(0)
        if (!_pixViewer.active)
            toggleViewer()
        _pixViewer.slideshowActive = true
    }

    function showGallery()
    {
        _stackView.pop(null)
        if (_stackView.currentItem)
            _stackView.currentItem.forceActiveFocus()
    }

    function showCollections()
    {
        if(currentRoute && currentRoute.objectName === "CollectionView")
            return

        if(_pixViewer.active)
            _stackView.pop()

        if(!currentRoute || currentRoute.objectName !== "CollectionView")
            _stackView.push(_collectionViewComponent)

        if (_stackView.currentItem)
            _stackView.currentItem.forceActiveFocus()
    }

    function showTags()
    {
        if(currentRoute && currentRoute.objectName === "TagsView")
            return

        if(_pixViewer.active)
            _stackView.pop()

        if(!currentRoute || currentRoute.objectName !== "TagsView")
            _stackView.push(_tagsViewComponent)

        if (_stackView.currentItem)
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

        if(!currentRoute || currentRoute.objectName !== "CollectionView")
        {
            _stackView.push(_collectionViewComponent)
        }

        if (_stackView.currentItem)
            _stackView.currentItem.openFolder(url, filters)
    }

    function openEditor(url, stack)
    {
        if (!url || String(url).length === 0)
            return

        stack.push(_editorComponent, ({url: url}))
    }

    function openExternalPics(pics, index)
    {
        const count = pics ? pics.length : 0
        if (count === 0)
            return

        const lastIndex = Math.max(count - 1, 0)
        const requestedIndex = typeof index === "number" ? index : 0
        const targetIndex = Math.min(Math.max(requestedIndex, 0), lastIndex)
        pixViewer.sourceModel = null
        pixViewer.viewer.clear()
        pixViewer.viewer.appendPics(pics)
        pixViewer.view(targetIndex)
        if(!pixViewer.active)
        {
            toggleViewer()
        }
    }

    function open(model, index, recursive = false)
    {
        const targetIndex = model.mappedFromSource(index)
        pixViewer.sourceModel = model
        pixViewer.syncFromSourceModel(targetIndex)
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
        const cleanUrls = (urls || []).filter((url) => url && String(url).length > 0)
        if (cleanUrls.length === 0)
            return

        let pic = cleanUrls[0]
        let props = ({'mode' : FB.FileDialog.Save,
                         'browser.settings.filterType' : FB.FMList.IMAGE,
                         'singleSelection' : true,
                         'suggestedFileName' : FB.FM.getFileInfo(pic).label,
                         'callback' : function(paths)
                         {
                             console.log("Sate to ", paths)
                             FB.FM.copy(cleanUrls, paths[0])

                         }})
        var dialog = fmDialogComponent.createObject(control, props)
        dialog.open()
    }

    function removeFiles(urls)
    {
        const cleanUrls = (urls || []).filter((url) => url && String(url).length > 0)
        if (cleanUrls.length === 0)
            return

        var dialog = _removeDialogComponent.createObject(control, ({'urls' : cleanUrls}))
        dialog.open()
    }

    function openFileWith(urls)
    {
        const cleanUrls = (urls || []).filter((url) => url && String(url).length > 0)
        if (cleanUrls.length === 0)
            return

        if(Maui.Handy.isAndroid)
        {
            FB.FM.openUrl(cleanUrls[0])
            return
        }

        _openWithDialog.urls = cleanUrls
        _openWithDialog.open()
    }
}
