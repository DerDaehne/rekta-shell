pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import KeyMap
import Rekta
import "ContactSheets.js" as ContactSheets
import "Glide.js" as Glide

TestCase {
    id: testCase

    name: "KeyMap"
    // Objects created inside an invisible test case are never rendered, so the contact sheet would stay empty.
    visible: true
    when: windowShown
    width: 800
    height: 700

    // What kglobalaccel replies by "component/action", as Qt key codes; an action not in it gets no reply, as in a
    // session without kglobalaccel.
    property var replies: ({})
    property int asks: 0

    readonly property int meta: 0x10000000
    readonly property int ctrl: 0x04000000
    readonly property int alt: 0x08000000

    Component {
        id: sceneComponent

        // A host as the shell's surfaces are: what no control takes goes to the key layers.
        Item {
            width: 800
            height: 700
            Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)

            Item {
                objectName: "outside"
                width: 100
                height: 40
                activeFocusOnTab: true
            }

            TextInput {
                objectName: "field"
                y: 50
                width: 200
                height: 40
            }

            KeyMap {
                objectName: "map"
                anchors.fill: parent
                launcher: QtObject {
                    function ask(service: string, path: string, iface: string, method: string, args: var, signature: string, done: var) {
                        testCase.asks++;
                        const reply = testCase.replies[`${args[0][0]}/${args[0][1]}`];
                        if (reply !== undefined)
                            done([[[reply, 0, 0, 0]]]);
                    }
                }
            }
        }
    }

    Component {
        id: holdComponent

        MetaHold {}
    }

    Component {
        id: askedSpyComponent

        SignalSpy {
            signalName: "asked"
        }
    }

    property Item scene
    property KeyMap map

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        asks = 0;
        replies = {
            "rekta-shell/start": 0x01000022,
            "rekta-shell/controls": meta | 0x41,
            "rekta-shell/notifications": meta | 0x4e,
            "ksmserver/Lock Session": meta | 0x4c,
            "ksmserver/Log Out": ctrl | alt | 0x01000007
        };
        scene = createTemporaryObject(sceneComponent, testCase);
        map = findChild(scene, "map");
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function shownRows(): var {
        return map.rows.map(row => `${row.text}: ${row.key}`);
    }

    function test_the_list_reads_the_session_s_keys_from_kglobalaccel_and_writes_them_as_rekta_does() {
        map.readKeys();
        compare(asks, 5, "one question per shortcut kglobalaccel holds");
        compare(shownRows(), ["den start öffnen oder schließen: Super", "die steuerung öffnen: Super+A", "die meldungen öffnen: Super+N", "sperren: Super+L", "abmelden, neu starten oder ausschalten: Ctrl+Alt+Delete", "diese liste: ?", "zurück oder schließen, was offen ist: Esc", "rückgängig machen: Ctrl+Z"]);
    }

    function test_a_key_the_user_changed_shows_as_changed_the_next_time_the_list_is_read() {
        map.readKeys();
        replies = Object.assign({}, replies, {
            "rekta-shell/controls": ctrl | alt | 0x53
        });
        map.readKeys();
        verify(shownRows().includes("die steuerung öffnen: Ctrl+Alt+S"), shownRows().join("; "));
    }

    function test_a_shortcut_with_no_key_bound_has_no_row() {
        replies = Object.assign({}, replies, {
            "rekta-shell/notifications": 0
        });
        map.readKeys();
        verify(!map.rows.some(row => row.text === "die meldungen öffnen"));
        compare(map.rows.length, 7);
    }

    function test_without_kglobalaccel_only_rekta_s_own_keys_are_listed() {
        replies = {};
        map.readKeys();
        compare(shownRows(), ["diese liste: ?", "zurück oder schließen, was offen ist: Esc", "rückgängig machen: Ctrl+Z"]);
    }

    function test_a_question_mark_outside_a_text_field_asks_for_the_list() {
        const asked = createTemporaryObject(askedSpyComponent, testCase, {
            target: map
        });
        findChild(scene, "outside").forceActiveFocus();
        keyClick("?");
        compare(asked.count, 1);
    }

    function test_a_question_mark_in_a_text_field_is_typed_and_asks_for_nothing() {
        const asked = createTemporaryObject(askedSpyComponent, testCase, {
            target: map
        });
        const field = findChild(scene, "field");
        field.forceActiveFocus();
        keyClick("?");
        compare(asked.count, 0);
        compare(field.text, "?");
    }

    function test_a_question_mark_with_ctrl_or_while_a_sheet_is_open_asks_for_nothing() {
        const asked = createTemporaryObject(askedSpyComponent, testCase, {
            target: map
        });
        findChild(scene, "outside").forceActiveFocus();
        keyClick("?", Qt.ControlModifier);
        map.show();
        keyClick("?");
        compare(asked.count, 0);
    }

    function test_escape_and_schliessen_close_the_list_and_tab_reaches_schliessen() {
        findChild(scene, "outside").forceActiveFocus();
        map.readKeys();
        map.show();
        const close = findChild(map, "schliessen");
        verify(close.activeFocus, "schließen takes the focus as it opens");
        keyClick(Qt.Key_Tab);
        verify(close.activeFocus, "and Tab comes round to it, the only control");
        keyClick(Qt.Key_Escape);
        tryVerify(() => !map.open);
        map.show();
        mouseClick(close);
        tryVerify(() => !map.open);
        verify(findChild(scene, "outside").activeFocus, "the focus is back where it was");
    }

    function test_a_list_shown_by_a_hold_gives_no_button_the_focus_and_shows_no_ring() {
        findChild(scene, "outside").forceActiveFocus();
        map.showHeld();
        const close = findChild(map, "schliessen");
        verify(!close.activeFocus);
        verify(!findChild(close, "ring").shown);
    }

    function test_a_list_asked_for_by_a_question_mark_gives_schliessen_the_focus() {
        map.showHeld();
        map.holdEnded();
        tryVerify(() => !map.open);
        map.showAsked();
        verify(findChild(map, "schliessen").activeFocus);
    }

    function test_a_hold_that_ends_does_not_close_a_list_asked_for_by_a_question_mark() {
        map.showAsked();
        map.showHeld();
        map.holdEnded();
        wait(0);
        verify(map.open);
        verify(!map.held, "it keeps the keyboard");
    }

    function test_a_list_shown_by_a_hold_goes_when_the_hold_ends() {
        map.showHeld();
        verify(map.open);
        map.holdEnded();
        tryVerify(() => !map.open);
    }

    function test_meta_held_alone_for_long_press_shows_the_map_and_its_end_hides_it() {
        const hold = createTemporaryObject(holdComponent, testCase);
        const shows = Glide.record(hold, "showing");
        const began = Date.now();
        hold.alone();
        verify(!hold.showing);
        tryCompare(hold, "showing", true, 3 * Tokens.durationLongPress);
        verify(shows[0].at - began >= 0.8 * Tokens.durationLongPress, "not before long-press");
        hold.ended();
        verify(!hold.showing);
    }

    function test_meta_ended_before_long_press_shows_nothing_and_leaves_the_start_its_key() {
        const hold = createTemporaryObject(holdComponent, testCase);
        hold.alone();
        verify(hold.waiting.running, "long-press runs");
        hold.ended();
        wait(Tokens.durationLongPress * 2);
        verify(!hold.showing, "nor after long-press");
        verify(!hold.takesStartKey(), "a short Meta opens the Start");
    }

    function test_the_meta_after_a_hold_that_showed_the_map_is_taken_from_the_start_once_in_either_order() {
        const hold = createTemporaryObject(holdComponent, testCase);
        hold.alone();
        tryCompare(hold, "showing", true, 3 * Tokens.durationLongPress);
        verify(hold.takesStartKey(), "the release's Meta before KWin's end");
        hold.ended();
        verify(!hold.takesStartKey(), "only that one");

        hold.alone();
        tryCompare(hold, "showing", true, 3 * Tokens.durationLongPress);
        hold.ended();
        verify(hold.takesStartKey(), "the release's Meta after KWin's end");
    }

    function test_a_new_meta_forgets_a_start_key_the_last_hold_left_untaken() {
        const hold = createTemporaryObject(holdComponent, testCase);
        hold.alone();
        tryCompare(hold, "showing", true, 3 * Tokens.durationLongPress);
        hold.ended();
        hold.alone();
        hold.ended();
        verify(!hold.takesStartKey());
    }

    function test_contact_sheet_of_the_list_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            map.readKeys();
            map.show();
            waitForRendering(scene);
            grabImage(scene).save(`keymap-${theme}.png`);
            map.close("");
            tryVerify(() => !map.open);
        }
    }
}
