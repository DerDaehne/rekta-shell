pragma Singleton

import QtQml

// plasma-workspace's session bus without a bus: a call goes nowhere.
QtObject {
    function asyncCall(message: var) {
    }
}
