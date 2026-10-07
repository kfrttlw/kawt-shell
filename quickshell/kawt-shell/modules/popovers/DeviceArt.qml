import QtQuick
import qs.config
import qs.components

// A tiny ThinkPad with the red nub, or a CRT + tower with a power LED.
// Every line is 18 columns so both pictures take the same space.
Column {
    id: root

    property bool laptop: true
    property bool blink: true

    // inline components can't see `root`, so the blink state is passed in
    component Cursor: Label {
        id: cursor

        property bool running: true

        text: "_"
        color: Colors.accent

        SequentialAnimation on opacity {
            running: cursor.running
            loops: Animation.Infinite

            PropertyAction { value: 1 }
            PauseAnimation { duration: 530 }
            PropertyAction { value: 0 }
            PauseAnimation { duration: 530 }
        }
    }

    // ------------------------------------------------------------ laptop
    Label {
        visible: root.laptop
        text: "  ____________    "
        color: Colors.dim
    }

    Row {
        visible: root.laptop

        Label {
            text: " | >"
            color: Colors.dim
        }

        // the hidden picture's cursor stays still: a blinking one would still redraw the window
        Cursor {
            running: root.blink && root.laptop
        }

        Label {
            text: "         |   "
            color: Colors.dim
        }
    }

    Label {
        visible: root.laptop
        text: " |            |   "
        color: Colors.dim
    }

    Label {
        visible: root.laptop
        text: " |____________|   "
        color: Colors.dim
    }

    Row {
        visible: root.laptop

        Label {
            text: "/ :::::"
            color: Colors.dim
        }

        Label {
            text: "●"
            color: Colors.themes.thinkpad.dark.accent // always the real red nub
        }

        Label {
            text: ":::::: \\  "
            color: Colors.dim
        }
    }

    Label {
        visible: root.laptop
        text: "\\______________/  "
        color: Colors.dim
    }

    // ----------------------------------------------------------- desktop
    Label {
        visible: !root.laptop
        text: " .----------. .--."
        color: Colors.dim
    }

    Row {
        visible: !root.laptop

        Label {
            text: " | >"
            color: Colors.dim
        }

        Cursor {
            running: root.blink && !root.laptop
        }

        Label {
            text: "       | |::|"
            color: Colors.dim
        }
    }

    Label {
        visible: !root.laptop
        text: " |          | |  |"
        color: Colors.dim
    }

    Row {
        visible: !root.laptop

        Label {
            text: " '----------' |"
            color: Colors.dim
        }

        Label {
            text: "●"
            color: Colors.accent
        }

        Label {
            text: " |"
            color: Colors.dim
        }
    }

    Label {
        visible: !root.laptop
        text: "    _|__|_    |__|"
        color: Colors.dim
    }

    Label {
        visible: !root.laptop
        text: "  [::::::::::]    "
        color: Colors.dim
    }
}
