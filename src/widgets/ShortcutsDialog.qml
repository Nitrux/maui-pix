import QtQuick.Controls

import org.mauikit.controls as Maui

Maui.SettingsDialog
{
    id: control

    Maui.Controls.title: i18n("Shortcuts")

    Maui.SectionGroup
    {
        title: i18n("Collection")
        description: i18n("Browse, select, and resize image grids with the keyboard.")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Open Image")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Enter" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Image Info")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Space" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Select Current Image")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "S" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Select All")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "A" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Increase Thumbnail Size")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "+" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Decrease Thumbnail Size")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "-" }
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("Viewer")
        description: i18n("Navigate and act on images while viewing them.")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Next Image")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Right" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Previous Image")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Left" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Open Editor")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "E" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Save As")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "S" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Delete Image")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "D" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Toggle Slideshow")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "S" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Fullscreen")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "F" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Focus Tag Bar")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "T" }
            }
        }
    }

    Maui.SectionGroup
    {
        title: i18n("General")

        Maui.FlexSectionItem
        {
            label1.text: i18n("Main View")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "Home" }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Preferences")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "," }
            }
        }

        Maui.FlexSectionItem
        {
            label1.text: i18n("Show Shortcuts")

            Maui.ToolActions
            {
                checkable: false
                autoExclusive: false

                Action { text: "Ctrl" }
                Action { text: "/" }
            }
        }
    }
}
