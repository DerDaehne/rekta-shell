pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets

TestCase {
    id: testCase

    name: "Combobox"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 600

    readonly property var apps: [
        { label: "firefox", value: "firefox.desktop", keywords: "browser web" },
        { label: "files", value: "dolphin.desktop" },
        { label: "konsole", value: "konsole.desktop", hint: "Ctrl Alt T" },
        { label: "kate", value: "kate.desktop", disabledReason: "already pinned" },
        { label: "system settings", value: "systemsettings.desktop" }
    ]
    property Item scene
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var combo
    property SignalSpy activated

    Component {
        id: sceneComponent

        Item {
            // Escapes nothing in front of it took.
            property int escapes: 0

            width: 1000
            height: 600
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    escapes++;
            }

            Column {
                x: 40
                y: 40
                width: 240
                spacing: Tokens.spaceM

                Button {
                    objectName: "before"
                    text: "before"
                }

                Combobox {
                    objectName: "combo"
                    width: parent.width
                    label: "app"
                    placeholder: "find an app"
                    options: testCase.apps
                }

                Button {
                    objectName: "after"
                    text: "after"
                }
            }
        }
    }

    Component {
        id: spyComponent

        SignalSpy {
            signalName: "activated"
        }
    }

    // A combobox in a scroller, with more to scroll to below it.
    Component {
        id: scrollerComponent

        Flickable {
            x: 500
            width: 300
            height: 300
            contentHeight: 900

            Combobox {
                objectName: "scrolled"
                y: 100
                width: 260
                options: testCase.apps
            }
        }
    }

    Component {
        id: sheetComponent

        // Comboboxes side by side on the current theme's ground: one to filter, one with a choice, one whose filter
        // matches nothing, and one disabled with its reason. The sheet opens each list in turn.
        Rectangle {
            width: 984
            height: 360
            color: Tokens.color.bg

            Row {
                x: Tokens.spaceL
                y: Tokens.spaceL
                spacing: Tokens.spaceL

                Combobox {
                    objectName: "filter"
                    width: 216
                    options: testCase.apps
                }

                Combobox {
                    objectName: "chosen"
                    width: 216
                    options: testCase.apps
                }

                Combobox {
                    objectName: "nomatch"
                    width: 216
                    options: testCase.apps
                }

                Combobox {
                    width: 216
                    options: testCase.apps
                    disabledReason: "no apps installed"
                }
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        scene = createTemporaryObject(sceneComponent, testCase);
        combo = findChild(scene, "combo");
        activated = createTemporaryObject(spyComponent, testCase, { target: combo });
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function input(of: var): var {
        return findChild(of, "input");
    }

    function list(of: var): var {
        return findChild(of, "list");
    }

    function rows(of: var): var {
        return Array.from(list(of).rows).filter(row => row.objectName === "option");
    }

    function labels(of: var): var {
        return rows(of).map(row => row.text);
    }

    function type(text: string) {
        for (const character of text)
            keyClick(character);
    }

    function focusAndType(of: var, text: string) {
        input(of).forceActiveFocus();
        type(text);
    }

    function inScene(item: var): point {
        return item.mapToItem(null, 0, 0);
    }

    // True where the pixel lies nearer the text colour than the ground.
    function inkAt(image: var, x: real, y: real): bool {
        const pixel = image.pixel(Math.round(x), Math.round(y));
        const distance = (a, b) => Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b);
        return distance(pixel, Tokens.color.textPrimary) < distance(pixel, Tokens.color.bg);
    }

    function inkIn(image: var, area: rect): int {
        let count = 0;
        for (let x = area.x; x < area.x + area.width; x++) {
            for (let y = area.y; y < area.y + area.height; y++)
                count += inkAt(image, x, y) ? 1 : 0;
        }
        return count;
    }

    function window(): Item {
        return testCase.Window.window.contentItem;
    }

    function test_the_field_is_an_input_box_with_the_combo_chevron_pointing_down_at_its_end() {
        const box = findChild(combo, "box");
        compare(box.height, Tokens.controlHeight);
        compare(box.radius, Tokens.radiusS);
        compare(box.border.width, Geometry.inputBorder);
        compare(box.border.color, Tokens.color.textContrastMedium);
        compare(input(combo).leftPadding, Geometry.inputPadding);
        compare(input(combo).rightPadding, 40, "the text stops where the button's room starts");
        compare(findChild(combo, "placeholder").text, "find an app");
        const button = findChild(combo, "button");
        compare(button.width, 36);
        compare(button.x + button.width, combo.width - 1, "inside the border");
        waitForRendering(scene);
        const image = grabImage(window());
        const at = inScene(button);
        const centreX = at.x + 14 + 4;
        const centreY = at.y + button.height / 2;
        verify(inkAt(image, centreX, centreY), "its point in the middle");
        verify(!inkAt(image, centreX, centreY - 3), "open above it");
        verify(inkAt(image, centreX - 3, centreY - 2), "an arm up to the left");
        verify(inkAt(image, centreX + 2, centreY - 2), "an arm up to the right");
        verify(!inkAt(image, centreX - 6, centreY - 2), "8px wide in all");
        verify(!inkAt(image, centreX + 5, centreY - 2));
        verify(!list(combo).visible, "no list in sight");
    }

    function test_the_chevron_points_up_while_the_list_is_open() {
        input(combo).forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(combo.expanded);
        waitForRendering(scene);
        const button = findChild(combo, "button");
        const image = grabImage(window());
        const at = inScene(button);
        const centreX = at.x + 14 + 4;
        const centreY = at.y + button.height / 2;
        verify(inkAt(image, centreX, centreY - 1), "its point in the middle");
        verify(!inkAt(image, centreX, centreY + 2), "open below it");
        verify(inkAt(image, centreX - 3, centreY + 1), "an arm down to the left");
        verify(inkAt(image, centreX + 2, centreY + 1), "an arm down to the right");
    }

    function test_typing_filters_the_list_which_floats_below_the_field_as_wide_as_it_at_least_with_the_focus_in_the_field() {
        focusAndType(combo, "kon");
        verify(combo.expanded, "typing opens it");
        compare(labels(combo), ["konsole"]);
        verify(input(combo).activeFocus, "the focus stays in the field");
        const surface = list(combo);
        verify(surface.visible);
        compare(surface.parent, window(), "it floats above the window's content");
        const field = inScene(findChild(combo, "box"));
        compare(surface.x, field.x, "at the field's leading edge");
        compare(surface.y, field.y + Tokens.controlHeight + Tokens.spaceXs, "space-xs below the field");
        compare(surface.side, "below");
        verify(surface.width >= combo.width);
        compare(surface.width, Math.max(Geometry.floatMinWidth, combo.width));
        keyClick(Qt.Key_Backspace);
        keyClick(Qt.Key_Backspace);
        keyClick(Qt.Key_Backspace);
        compare(labels(combo), apps.map(app => app.label), "every option again, in its own order");
    }

    function test_the_filter_matches_word_starts_and_keywords_best_first_as_the_start_search_does() {
        focusAndType(combo, "s");
        compare(labels(combo)[0], "system settings", "the name starts with it");
        compare(labels(combo).slice(1), ["files", "konsole"], "then the names that only hold it");
        keyClick(Qt.Key_Backspace);
        type("web");
        compare(labels(combo), ["firefox"], "by a keyword");
        compare(combo.active, 0, "the keys start on the best match");
    }

    function test_when_nothing_matches_a_sentence_on_a_hairline_says_so_in_the_hosts_words() {
        combo.noMatch = typed => `keine app passt zu „${typed}“.`;
        focusAndType(combo, "xyz");
        verify(combo.expanded);
        compare(rows(combo).length, 0);
        const empty = findChild(combo, "empty");
        verify(empty.visible);
        compare(empty.text, "keine app passt zu „xyz“.");
        compare(findChild(empty, "sentence").color, Tokens.color.textContrastHigh);
        verify(findChild(empty, "line").visible);
        compare(empty.x, Tokens.spaceM);
        compare(combo.active, -1);
        keyClick(Qt.Key_Return);
        compare(activated.count, 0, "Enter chooses nothing");
    }

    function test_down_and_alt_down_open_the_list_on_the_chosen_option() {
        combo.take(apps[2]);
        for (const modifiers of [Qt.NoModifier, Qt.AltModifier]) {
            input(combo).forceActiveFocus();
            keyClick(Qt.Key_Down, modifiers);
            verify(combo.expanded, `${modifiers}`);
            compare(combo.active, 2);
            keyClick(Qt.Key_Escape);
            verify(!combo.expanded);
        }
    }

    function test_up_and_down_move_the_active_option_around_the_list_while_the_focus_stays_in_the_field() {
        input(combo).forceActiveFocus();
        keyClick(Qt.Key_Down);
        compare(combo.active, -1, "nothing chosen, no option active");
        keyClick(Qt.Key_Down);
        compare(combo.active, 0);
        keyClick(Qt.Key_Up);
        compare(combo.active, 4, "up from the first is the last");
        keyClick(Qt.Key_Down);
        compare(combo.active, 0, "down from the last is the first");
        keyClick(Qt.Key_Down);
        verify(input(combo).activeFocus);
        const row = rows(combo)[1];
        verify(row.active);
        verify(findChild(row, "tint").visible, "in the hover colour");
        const ring = findChild(row, "ring");
        verify(ring.visible, "with the focus ring");
        compare(ring.border.color, Tokens.color.focus);
        compare(ring.offset, -2, "2px inside the row");
        verify(!findChild(rows(combo)[0], "ring").visible);
        verify(row.Accessible.selected, "the screen reader hears it as the selected option");
    }

    function test_the_active_option_is_drawn_with_the_ring_and_the_hover_colour() {
        input(combo).forceActiveFocus();
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        waitForRendering(scene);
        const image = grabImage(window());
        const row = rows(combo)[0];
        const at = inScene(row);
        const ring = image.pixel(at.x + 1, at.y + row.height / 2);
        compare(Qt.colorEqual(ring, Tokens.color.focus), true, "the ring 2px wide inside its leading edge");
        const plain = image.pixel(at.x + row.width / 2, at.y + row.height + 2);
        const tinted = image.pixel(at.x + row.width - 40, at.y + 6);
        verify(!Qt.colorEqual(plain, tinted), "the hover colour on the active row only");
    }

    function test_enter_chooses_the_active_option_and_the_choice_carries_a_tick_without_a_box() {
        focusAndType(combo, "kon");
        keyClick(Qt.Key_Return);
        verify(!combo.expanded);
        compare(combo.value, "konsole.desktop");
        compare(input(combo).text, "konsole");
        compare(activated.count, 1);
        compare(activated.signalArguments[0][0], "konsole.desktop");
        verify(input(combo).activeFocus);
        keyClick(Qt.Key_Down);
        compare(labels(combo), apps.map(app => app.label), "its own words filter nothing");
        compare(combo.active, 2, "the keys start on the choice");
        const options = rows(combo);
        compare(options.map(row => row.checked), [false, false, true, false, false]);
        const chosen = options[2];
        verify(findChild(chosen, "tick").visible);
        verify(!findChild(chosen, "check").visible, "no box");
        compare(findChild(chosen, "label").x, Tokens.spaceM + 10 + 2 + Tokens.spaceS, "after the tick's room");
        compare(findChild(options[0], "label").x, findChild(chosen, "label").x, "which every option keeps");
        waitForRendering(scene);
        const image = grabImage(window());
        const slot = row => {
            const at = inScene(row);
            return Qt.rect(at.x + Tokens.spaceM - 2, at.y + 4, 14, row.height - 8);
        };
        verify(inkIn(image, slot(chosen)) > 6, "a tick is drawn on the choice");
        // The active row's ring runs through its slot, so the ink count looks at a row with neither.
        verify(inkIn(image, slot(options[4])) === 0, "and none on another option");
    }

    function test_escape_closes_then_clears_and_only_then_lets_the_key_go_on() {
        focusAndType(combo, "kon");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        verify(!combo.expanded, "the first closes");
        compare(input(combo).text, "konsole");
        compare(scene.escapes, 0);
        keyClick(Qt.Key_Escape);
        compare(input(combo).text, "", "the second clears");
        compare(combo.chosen, null);
        compare(activated.count, 2);
        compare(activated.signalArguments[1][0], null);
        compare(scene.escapes, 0);
        keyClick(Qt.Key_Escape);
        compare(scene.escapes, 1, "the third is free to go back");
    }

    function test_tab_closes_and_moves_on() {
        focusAndType(combo, "f");
        verify(combo.expanded);
        keyClick(Qt.Key_Tab);
        verify(!combo.expanded);
        verify(findChild(scene, "after").activeFocus);
    }

    function test_leaving_with_other_text_puts_the_last_choice_back() {
        combo.take(apps[1]);
        focusAndType(combo, "zzz");
        findChild(scene, "after").forceActiveFocus();
        compare(input(combo).text, "files");
        compare(combo.value, "dolphin.desktop");
        compare(activated.count, 0);
    }

    function test_leaving_with_an_options_words_chooses_it_and_leaving_empty_takes_the_choice_away() {
        focusAndType(combo, "Firefox");
        findChild(scene, "after").forceActiveFocus();
        compare(combo.value, "firefox.desktop");
        compare(input(combo).text, "firefox");
        compare(activated.count, 1);
        input(combo).selectAll();
        input(combo).forceActiveFocus();
        keyClick(Qt.Key_Backspace);
        findChild(scene, "after").forceActiveFocus();
        compare(combo.chosen, null);
        compare(activated.signalArguments[1][0], null);
    }

    function test_clear_empties_the_field_and_the_choice() {
        combo.take(apps[0]);
        combo.clear();
        compare(input(combo).text, "");
        compare(combo.value, undefined);
        compare(activated.count, 0, "it is no choice made here");
    }

    function test_a_press_on_the_field_opens_and_a_press_on_an_option_chooses_it() {
        mouseClick(input(combo));
        verify(combo.expanded);
        verify(input(combo).activeFocus);
        waitForRendering(scene);
        mouseClick(rows(combo)[4]);
        verify(!combo.expanded);
        compare(combo.value, "systemsettings.desktop");
        verify(input(combo).activeFocus, "the focus stays in the field");
    }

    function test_a_press_on_the_chevron_opens_and_closes_and_puts_the_focus_in_the_field() {
        const button = findChild(combo, "button");
        mouseClick(button);
        verify(combo.expanded);
        verify(input(combo).activeFocus);
        mouseClick(button);
        verify(!combo.expanded);
    }

    function test_the_pointer_over_an_option_makes_it_the_active_one() {
        mouseClick(input(combo));
        waitForRendering(scene);
        const row = rows(combo)[3];
        mouseMove(row, 30, row.height / 2);
        tryCompare(combo, "active", 3);
    }

    function test_a_press_outside_closes_the_list_and_leaves_the_choice() {
        combo.take(apps[0]);
        mouseClick(input(combo));
        verify(combo.expanded);
        mouseClick(scene, 900, 500);
        verify(!combo.expanded);
        compare(combo.value, "firefox.desktop");
    }

    function test_on_touch_a_tap_on_the_field_opens_and_a_tap_on_an_option_chooses_it() {
        const touch = touchEvent(scene);
        const field = inScene(input(combo));
        touch.press(0, scene, field.x + 20, field.y + 10).commit();
        touch.release(0, scene, field.x + 20, field.y + 10).commit();
        verify(combo.expanded);
        verify(input(combo).activeFocus);
        waitForRendering(scene);
        const row = inScene(rows(combo)[1]);
        touch.press(0, scene, row.x + 30, row.y + 10).commit();
        touch.release(0, scene, row.x + 30, row.y + 10).commit();
        verify(!combo.expanded);
        compare(combo.value, "dolphin.desktop");
    }

    function test_a_disabled_option_stays_greyed_says_why_in_its_label_and_cannot_be_chosen() {
        focusAndType(combo, "kat");
        const row = rows(combo)[0];
        compare(row.label, "kate (already pinned)");
        compare(findChild(row, "label").color, Tokens.color.disabled);
        keyClick(Qt.Key_Return);
        verify(combo.expanded, "Enter on it does nothing");
        compare(activated.count, 0);
        waitForRendering(scene);
        mouseClick(row);
        compare(activated.count, 0, "nor a press");
        findChild(scene, "after").forceActiveFocus();
        compare(input(combo).text, "", "nor its words typed whole");
    }

    function test_disabled_it_greys_stays_focusable_says_why_below_and_never_opens() {
        combo.take(apps[0]);
        combo.disabledReason = "no apps installed";
        compare(findChild(combo, "box").border.color, Tokens.color.disabled);
        compare(input(combo).color, Tokens.color.disabled);
        compare(findChild(combo, "chevron").color, Tokens.color.disabled);
        const why = findChild(combo, "why");
        verify(why.visible);
        compare(why.text, "no apps installed");
        compare(why.y, Tokens.controlHeight + Tokens.spaceXs);
        compare(combo.implicitHeight, why.y + why.height);
        compare(input(combo).Accessible.description, "no apps installed");
        findChild(scene, "before").forceActiveFocus();
        keyClick(Qt.Key_Tab);
        verify(input(combo).activeFocus, "still in the focus order");
        keyClick(Qt.Key_Down);
        type("k");
        verify(!combo.expanded);
        compare(input(combo).text, "firefox", "no typing");
        mouseClick(findChild(combo, "button"));
        verify(!combo.expanded);
    }

    function test_the_list_comes_in_as_every_floating_surface_does_and_at_once_under_reduced_motion() {
        input(combo).forceActiveFocus();
        keyClick(Qt.Key_Down);
        compare(list(combo).entry, 1, "at once");
        keyClick(Qt.Key_Escape);
        Prefs.motion = "on";
        keyClick(Qt.Key_Down);
        verify(list(combo).entry < 1, "it fades in");
        compare(findChild(list(combo), "comingIn").duration, Tokens.durationFloat);
        tryCompare(list(combo), "entry", 1, 4 * Tokens.durationFloat);
    }

    function test_the_list_follows_the_field_when_its_scroller_moves() {
        const view = createTemporaryObject(scrollerComponent, scene);
        const scrolled = findChild(view, "scrolled");
        input(scrolled).forceActiveFocus();
        keyClick(Qt.Key_Down);
        const before = list(scrolled).y;
        view.contentY = 40;
        compare(list(scrolled).y, before - 40);
    }

    function test_out_of_sight_it_closes() {
        input(combo).forceActiveFocus();
        keyClick(Qt.Key_Down);
        combo.visible = false;
        verify(!combo.expanded);
    }

    function test_the_screen_reader_hears_a_combobox_with_a_list_of_options() {
        const field = input(combo);
        compare(field.Accessible.role, Accessible.ComboBox);
        compare(field.Accessible.name, "app");
        verify(field.Accessible.editable);
        field.forceActiveFocus();
        keyClick(Qt.Key_Down);
        if ("expanded" in field.Accessible)
            verify(field.Accessible.expanded);
        compare(list(combo).Accessible.role, Accessible.List);
        compare(rows(combo)[0].Accessible.role, Accessible.ListItem);
        compare(rows(combo)[3].Accessible.name, "kate (already pinned)");
    }

    // Each pair of theme and density, with each list open in turn: a filter typed, the choice, nothing matching.
    function test_contact_sheet_of_comboboxes_in_both_themes_and_densities() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, scene);
                const chosen = findChild(sheet, "chosen");
                chosen.take(apps[2]);
                const opened = [["filter", () => focusAndType(findChild(sheet, "filter"), "s")], ["chosen", () => {
                            input(chosen).forceActiveFocus();
                            keyClick(Qt.Key_Down);
                        }], ["nomatch", () => focusAndType(findChild(sheet, "nomatch"), "xyz")]];
                for (const [name, open] of opened) {
                    open();
                    verify(findChild(sheet, name).expanded, `${theme} ${density} ${name}`);
                    waitForRendering(sheet);
                    grabImage(sheet.Window.window.contentItem).save(`combobox-sheet-${theme}-${density}-${name}.png`);
                }
                sheet.destroy();
            }
        }
    }
}
