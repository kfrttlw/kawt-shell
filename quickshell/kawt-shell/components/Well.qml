import QtQuick
import qs.config

// A sunk place for a list, a graph or a text, as old systems had them (raised frames); with flat
// frames just a thin line around it.
Rectangle {
    color: Colors.well

    Bevel {
        style: "sunk"
    }
}
