import QtQuick
import QtQuick.Controls
import QtQml
import QtQuick.Layouts

import org.mauikit.controls as Maui
import org.mauikit.imagetools as IT
import org.maui.pix as Pix

Maui.SettingsDialog
{
    id: control

    readonly property var ocrSegModes: [
        {
            text: i18n("Auto"),
            value: IT.OCR.Auto,
            description: i18n("Let Pix choose the most suitable page layout automatically.")
        },
        {
            text: i18n("Auto with Orientation"),
            value: IT.OCR.Auto_OSD,
            description: i18n("Detect both the page layout and its rotation before reading the text.")
        },
        {
            text: i18n("Single Column"),
            value: IT.OCR.SingleColumn,
            description: i18n("Best for article-style pages or screenshots with one vertical column of text.")
        },
        {
            text: i18n("Single Line"),
            value: IT.OCR.SingleLine,
            description: i18n("Best for captions, labels, or any image that only contains one line of text.")
        },
        {
            text: i18n("Single Block"),
            value: IT.OCR.SingleBlock,
            description: i18n("Best for a single paragraph or one compact block of text.")
        },
        {
            text: i18n("Single Word"),
            value: IT.OCR.SingleWord,
            description: i18n("Best for isolated words, buttons, and short labels.")
        }
    ]

    function ocrSegModeIndex(value)
    {
        for (let i = 0; i < ocrSegModes.length; ++i)
        {
            if (ocrSegModes[i].value === value)
                return i
        }

        return 0
    }

    function ocrSegModeDescription(value)
    {
        return ocrSegModes[ocrSegModeIndex(value)].description
    }

    function ocrBlockTypeDescription(value)
    {
        switch (value)
        {
        case 0:
            return i18n("Highlight each detected word separately.")
        case 1:
            return i18n("Highlight full lines of text for easier reading.")
        case 2:
            return i18n("Highlight larger paragraph blocks instead of smaller fragments.")
        default:
            return i18n("Highlight each detected word separately.")
        }
    }

    function ocrSelectionDescription(value)
    {
        switch (value)
        {
        case 0:
            return i18n("Hold Shift and drag across text blocks to add them one by one to the selection.")
        case 1:
            return i18n("Hold Shift and drag a rectangle to select every detected block inside the area.")
        default:
            return i18n("Hold Shift and drag across text blocks to add them one by one to the selection.")
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Behavior")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Auto Reload")
            label2.text: i18n("Watch for changes in the collection sources.")

            Switch
            {
                checkable: true
                checked: browserSettings.autoReload
                onToggled: browserSettings.autoReload = !browserSettings.autoReload
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Collection")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Fit")
            label2.text: i18n("Fit the previews and preserve the aspect ratio.")

            Switch
            {
                checkable: true
                checked: browserSettings.fitPreviews
                onToggled: browserSettings.fitPreviews = !browserSettings.fitPreviews
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Image Titles")
            label2.text: i18n("Show the file name of the images.")

            Switch
            {
                checkable: true
                checked: browserSettings.showLabels
                onToggled: browserSettings.showLabels = !browserSettings.showLabels
            }
        }      

        Maui.FlexSectionItem
        {
            label1.text: i18n("GPS Tags")
            label2.text: i18n("Show GPS tags.")

            Switch
            {
                checkable: true
                checked: browserSettings.gpsTags
                onToggled: browserSettings.gpsTags = !browserSettings.gpsTags
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Text Detection")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Enable Text Detection")
            label2.text: i18n("Detect selectable text in images while viewing them.")

            Switch
            {
                checked: viewerSettings.enableOCR
                onToggled: viewerSettings.enableOCR = !viewerSettings.enableOCR
            }
        }

        Maui.FlexSectionItem
        {
            enabled: viewerSettings.enableOCR
            label1.text: i18n("Image Preprocessing")
            label2.text: i18n("Improve contrast before recognition. Helpful for photos and low-contrast scans, but it can be slower.")

            Switch
            {
                checked: viewerSettings.ocrPreprocessing
                onToggled: viewerSettings.ocrPreprocessing = !viewerSettings.ocrPreprocessing
            }
        }

        Maui.FlexSectionItem
        {
            enabled: viewerSettings.enableOCR
            label1.text: i18n("Page Segmentation")
            label2.text: control.ocrSegModeDescription(viewerSettings.ocrSegMode)

            ComboBox
            {
                editable: false
                model: control.ocrSegModes.map((mode) => mode.text)
                currentIndex: control.ocrSegModeIndex(viewerSettings.ocrSegMode)
                onActivated: viewerSettings.ocrSegMode = control.ocrSegModes[currentIndex].value
            }
        }

        Maui.FlexSectionItem
        {
            enabled: viewerSettings.enableOCR
            label1.text: i18n("Confidence Threshold")
            label2.text: i18n("Ignore OCR results below this confidence percentage. Lower values keep more text but may include more mistakes.")

            SpinBox
            {
                from: 1
                to: 100
                value: viewerSettings.ocrConfidenceThreshold
                onValueModified: viewerSettings.ocrConfidenceThreshold = value
            }
        }

        Maui.FlexSectionItem
        {
            enabled: viewerSettings.enableOCR
            label1.text: i18n("Highlight Units")
            label2.text: control.ocrBlockTypeDescription(viewerSettings.ocrBlockType)

            Maui.ToolActions
            {
                autoExclusive: true

                Action
                {
                    text: i18n("Word")
                    checked: viewerSettings.ocrBlockType === 0
                    onTriggered: viewerSettings.ocrBlockType = 0
                }

                Action
                {
                    text: i18n("Line")
                    checked: viewerSettings.ocrBlockType === 1
                    onTriggered: viewerSettings.ocrBlockType = 1
                }

                Action
                {
                    text: i18n("Paragraph")
                    checked: viewerSettings.ocrBlockType === 2
                    onTriggered: viewerSettings.ocrBlockType = 2
                }
            }
        }

        Maui.FlexSectionItem
        {
            enabled: viewerSettings.enableOCR
            label1.text: i18n("Selection Mode")
            label2.text: control.ocrSelectionDescription(viewerSettings.ocrSelectionType)

            Maui.ToolActions
            {
                autoExclusive: true

                Action
                {
                    text: i18n("Free")
                    checked: viewerSettings.ocrSelectionType === 0
                    onTriggered: viewerSettings.ocrSelectionType = 0
                }

                Action
                {
                    text: i18n("Rectangular")
                    checked: viewerSettings.ocrSelectionType === 1
                    onTriggered: viewerSettings.ocrSelectionType = 1
                }
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Viewer")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Tag Bar")
            label2.text: i18n("Easy way to add, remove and modify the tags of the current image.")

            Switch
            {
                checkable: true
                checked: viewerSettings.tagBarVisible
                onToggled: toogleTagbar()
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Preview Bar")
            label2.text: i18n("Show a strip of nearby images while viewing the current one.")
            Switch
            {
                checkable: true
                checked: viewerSettings.previewBarVisible
                onToggled: tooglePreviewBar()
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Presentation")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Slide Interval")
            label2.text: i18n("How long each image is shown before advancing.")

            SpinBox
            {
                from: 1
                to: 60
                value: viewerSettings.slideshowInterval
                onValueModified: viewerSettings.slideshowInterval = value

                textFromValue: (val) => i18np("%1 second", "%1 seconds", val)
                valueFromText: (text) => parseInt(text)
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Loop")
            label2.text: i18n("Restart from the first image after reaching the end.")

            Switch
            {
                checkable: true
                checked: viewerSettings.slideshowLoop
                onToggled: viewerSettings.slideshowLoop = !viewerSettings.slideshowLoop
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Sources")

        ColumnLayout
        {
            Layout.fillWidth: true
            spacing: Maui.Style.space.medium

            Repeater
            {
                id: _sourcesList

                model: Pix.Collection.sourcesModel


                delegate: Maui.ListDelegate
                {
                    Layout.fillWidth: true

                    template.iconSource: modelData.icon
                    template.iconSizeHint: Maui.Style.iconSizes.small
                    template.label1.text: modelData.label
                    template.label2.text: modelData.path.replace("file://", "")

                    template.content: ToolButton
                    {
                        icon.name: "edit-clear"
                        flat: true
                        onClicked:
                        {
                            Pix.Collection.removeSources(modelData.path)
                        }
                    }
                }
            }

            Button
            {
                Layout.fillWidth: true
                text: i18n("Add")
                onClicked:
                {
                    let props = ({'browser.settings.onlyDirs' : true,
                                     'callback' : function(urls)
                                     {
                                         Pix.Collection.addSources(urls)
                                     }
                                 })
                    var dialog = fmDialogComponent.createObject(root, props)
                    dialog.open()
                }
            }
        }
    }

}
