pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "KeyLayers"
    visible: true
    when: windowShown
    width: 600
    height: 400

    Component {
        id: sceneComponent

        // The outer item stands for whatever is beyond the host's root: it sees only the keys no layer used.
        Item {
            width: 600
            height: 400
            Keys.onPressed: event => {
                testCase.passed = [...testCase.passed, event.key];
            }

            Item {
                objectName: "host"
                anchors.fill: parent
                Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)

                Button {
                    objectName: "button"
                    text: "save"
                }

                TextInput {
                    objectName: "textInput"
                    y: 60
                    width: 200
                    text: "name"
                }

                TextEdit {
                    objectName: "textEdit"
                    y: 100
                    width: 200
                    text: "notes"
                }

                Field {
                    objectName: "field"
                    y: 140
                    label: "name"
                }
            }
        }
    }

    property Item scene
    property var removers: []
    property var calls: []
    property var passed: []

    function init() {
        scene = createTemporaryObject(sceneComponent, testCase);
        calls = [];
        passed = [];
    }

    function cleanup() {
        for (const remove of removers)
            remove();
        removers = [];
    }

    // A layer that writes down each key it sees and uses the keys in `uses`.
    function addLayer(priority, uses) {
        removers.push(KeyLayers.on(priority, event => {
            calls = [...calls, priority];
            return uses.includes(event.key);
        }));
    }

    function focusHost() {
        findChild(scene, "host").forceActiveFocus();
    }

    function test_the_higher_priority_sees_a_key_first() {
        addLayer(10, []);
        addLayer(40, []);
        addLayer(20, []);
        focusHost();
        keyClick(Qt.Key_A);
        compare(calls, [40, 20, 10]);
    }

    function test_a_layer_that_uses_a_key_stops_it_there() {
        addLayer(10, []);
        addLayer(20, [Qt.Key_Escape]);
        addLayer(30, []);
        focusHost();
        keyClick(Qt.Key_Escape);
        compare(calls, [30, 20], "nothing below the layer that used it");
        compare(passed, [], "nor anything outside");
    }

    function test_a_key_nobody_wants_passes_through() {
        addLayer(10, [Qt.Key_Escape]);
        focusHost();
        keyClick(Qt.Key_B);
        compare(calls, [10]);
        compare(passed, [Qt.Key_B]);
    }

    function test_a_removed_layer_sees_no_more_keys() {
        addLayer(10, []);
        focusHost();
        removers.pop()();
        keyClick(Qt.Key_A);
        compare(calls, []);
    }

    function test_components_take_their_keys_before_any_layer() {
        addLayer(45, [Qt.Key_Space, Qt.Key_Escape]);
        const button = findChild(scene, "button");
        let clicked = 0;
        button.clicked.connect(() => clicked++);
        button.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(clicked, 1);
        compare(calls, [], "the button used Space on its own item");
        keyClick(Qt.Key_Escape);
        compare(calls, [45], "a key it does not use reaches the layers");
    }

    function test_escape_is_free_only_outside_text_fields_menus_and_modals() {
        verify(KeyLayers.escapeIsFree(findChild(scene, "button")));
        verify(KeyLayers.escapeIsFree(null), "with nothing focused");
        verify(!KeyLayers.escapeIsFree(findChild(scene, "textInput")));
        verify(!KeyLayers.escapeIsFree(findChild(scene, "textEdit")));
        verify(!KeyLayers.escapeIsFree(findChild(findChild(scene, "field"), "input")), "the field's input");
        const modal = findChild(scene, "host");
        KeyLayers.opened(modal);
        verify(!KeyLayers.escapeIsFree(findChild(scene, "button")), "a modal is open");
        KeyLayers.closed(modal);
        verify(KeyLayers.escapeIsFree(findChild(scene, "button")));
    }

    function test_a_layer_gets_the_focused_item_to_ask_about_escape() {
        let free;
        removers.push(KeyLayers.on(10, (event, focusItem) => {
            free = KeyLayers.escapeIsFree(focusItem);
            return true;
        }));
        findChild(scene, "button").forceActiveFocus();
        keyClick(Qt.Key_Escape);
        verify(free, "from a button");
        findChild(scene, "textInput").forceActiveFocus();
        keyClick(Qt.Key_Escape);
        verify(!free, "from a text field");
    }
}
