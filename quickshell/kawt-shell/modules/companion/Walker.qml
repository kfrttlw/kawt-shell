import QtQuick

// Where he goes, a cell per step of his (Companion.step): to a place you send him (`goal`:
// the bowl), or wherever he likes while he's `free`, with a rest in between.
QtObject {
    id: root

    property real x: 0 // in cells
    property real min: 0
    property real max: 10
    property real goal: -1 // a place to get to first, faster
    property bool free: true // awake and idle: he may wander
    property int facing: 1
    property bool moving: false
    property real target: 0
    property int rest: 8

    // back inside when the room gets smaller
    onMaxChanged: x = Math.max(min, Math.min(max, x))

    function tick(): void {
        if (goal >= 0) {
            const g = Math.max(min, Math.min(max, goal));
            facing = g > x ? 1 : g < x ? -1 : facing;
            x = Math.abs(g - x) <= 2 ? g : x + facing * 2;
            moving = x !== g;
            if (!moving)
                goal = -1;
            return;
        }
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
