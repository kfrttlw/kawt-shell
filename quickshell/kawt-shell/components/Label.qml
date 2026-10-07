import QtQuick
import qs.config

// Plain text unless a label asks for more (textFormat: Text.StyledText). Qt's default would
// read anything that looks like HTML as HTML, and a lot of what kawt shows comes from outside:
// wifi names and bluetooth devices nearby, track and window titles (web pages), notification
// buttons. A network named <img src=http://...> would make kawt fetch that address.
Text {
    textFormat: Text.PlainText
    color: Colors.fg
    font.family: Metrics.fontFamily
    font.pixelSize: Metrics.fontSize
}
