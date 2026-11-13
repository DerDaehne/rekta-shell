import QtQuick

// How many notifications the shell holds unseen, for the lock screen's status area (shell.md, "The lock and sign-in
// screen": the number of new messages). Anything but a whole number from 0 up, as from a stranger on the bus, is none.
QtObject {
    property int count: 0

    function take(value: var) {
        count = Number.isInteger(value) && value >= 0 && value < 2 ** 31 ? value : 0;
    }
}
