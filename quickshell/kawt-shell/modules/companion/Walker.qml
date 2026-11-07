import QtQuick

// Where she goes on the desktop, a step per beat of hers (Companion.step): wherever she likes
// while she's `free`, with a rest in between.
QtObject {
    id: root

    property real x: 0 // in steps
    property real min: 0
    property real max: 10
    property bool free: true // awake and idle: she may wander
    property int facing: 1
    property bool moving: false
    property real target: 0
    property int rest: 8

    // back inside when the room gets smaller
    onMaxChanged: x = Math.max(min, Math.min(max, x))

    function tick(): void {
        if (!free) {
            moving = false;
            return;
        }
        if (moving) {
            x += facing;
            if ((facing > 0 && x >= target) || (facing < 0 && x <= target)) {
                x = target;
                moving = false;
                rest = 15 + Math.floor(Math.random() * 45);
            }
        } else if (--rest <= 0) {
            target = Math.round(min + Math.random() * (max - min));
            facing = target > x ? 1 : -1;
            moving = Math.abs(target - x) >= 2;
            rest = 20;
        }
    }
}
