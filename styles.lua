-- ManaHelper Styles and Configuration Constants
ManaHelperStyles = {
    Window = {
        Width = 250,
        Height = 400,
        Backdrop = {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        },
        Colors = {
            Background = {0.02, 0.02, 0.02, 0.9},
            Border = {0.15, 0.15, 0.15, 1},
            Title = {0.1, 0.9, 1, 1}
        }
    },
    Bar = {
        Texture = "Interface\\TargetingFrame\\UI-StatusBar", -- Bar texture
        Colors = {
            Mana = {0, 0.6, 1, 0.7},
            Selected = {0.2, 0.8, 0.2, 0.9},
            Background = {0.1, 0.1, 0.1, 0.6}
        }
    },
    Button = {
        Backdrop = {
            bgFile = "Interface\\Buttons\\UI-Listbox-Highlight",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        },
        Colors = {
            Normal = {0.2, 0.2, 0.2, 0.5},
            Hover = {0.4, 0.4, 1.0, 0.5},
            Selected = {0, 0.6, 0.1, 0.7}
        }
    }
}
