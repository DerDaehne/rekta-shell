pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Notices
import Panel
import Rekta

TestCase {
    id: testCase

    name: "Panel"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 720

    // What the panel asked the host to run, and the power profiles chosen in it, oldest first.
    property var commands: []
    property var chosenProfiles: []
    property Item scene
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var side
    property var controls
    property NoticeBoard board
    property Toaster toaster

    // What lies behind the panel: a place with a title, a line and the control that opened it.
    component Behind: Rectangle {
        color: Tokens.color.bg

        Column {
            x: Tokens.spaceL
            y: Tokens.spaceL
            width: parent.width - 2 * Tokens.spaceL
            spacing: Tokens.spaceM

            Title {
                width: parent.width
                text: "nightly builds"
            }

            Body {
                width: parent.width
                text: "The builds of every branch, run at two each night and kept for thirty days."
            }

            Button {
                objectName: "opener"
                text: "steuerung"
            }
        }
    }

    component ShellPanel: SidePanel {
        id: panel

        property alias controls: controlsFacet

        titles: ["steuerung", "meldungen"]

        Controls {
            id: controlsFacet

            objectName: "controls"
            hasPowerProfiles: true
            onRun: command => testCase.commands = [...testCase.commands, command]
            onPowerProfileChosen: profile => testCase.chosenProfiles = [...testCase.chosenProfiles, profile]
        }

        Item {
            objectName: "messages"
        }
    }

    Component {
        id: sceneComponent

        Item {
            width: 900
            height: 640

            Behind {
                anchors.fill: parent
            }

            Toaster {
                id: region

                objectName: "toaster"
                width: parent.width
                clock: () => 0
            }

            // As the shell has it: "nicht stören" makes the board quiet.
            NoticeBoard {
                objectName: "board"
                toaster: region
                quiet: scenePanel.controls.doNotDisturb
            }

            ShellPanel {
                id: scenePanel

                objectName: "panel"
                anchors.fill: parent
            }
        }
    }

    Component {
        id: spyComponent

        SignalSpy {}
    }

    // Something behind the panel that scrolls.
    Component {
        id: scrollerBehindComponent

        Flickable {
            anchors.fill: parent
            z: -1
            contentHeight: 5000
        }
    }

    // A group whose one row is absent, such as one waiting for a service.
    Component {
        id: absentGroupComponent

        PanelGroup {
            title: "verbindungen"

            PanelRow {
                label: "wlan"
                present: false

                Toggle {}
            }
        }
    }

    Component {
        id: contactComponent

        // The panel open over a place, as wide as a small window.
        Item {
            width: 760
            height: 640

            Behind {
                anchors.fill: parent
            }

            ShellPanel {
                objectName: "panel"
                anchors.fill: parent
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        commands = [];
        chosenProfiles = [];
        scene = createTemporaryObject(sceneComponent, testCase);
        side = findChild(scene, "panel");
        controls = side.controls;
        board = findChild(scene, "board");
        toaster = findChild(scene, "toaster");
        named("opener").forceActiveFocus();
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function named(name: string): var {
        return findChild(scene, name);
    }

    function control(name: string): var {
        return findChild(controls, name);
    }

    // The row a control stands in.
    function rowOf(item: var): var {
        let row = item;
        while (row && !(row instanceof PanelRow))
            row = row.parent;
        return row;
    }

    // A signal as a notification has them, to connect() to; the test emit()s it.
    function signal() {
        const handlers = [];
        return {
            connect: handler => handlers.push(handler),
            emit: (...args) => handlers.forEach(handler => handler(...args))
        };
    }

    // A notification as the server hands it over, in plain JS (see tst_notices).
    function notify(properties) {
        const fake = Object.assign({
            lastGeneration: false,
            appName: "chat",
            appIcon: "",
            summary: "anna",
            body: "lunch at noon?",
            urgency: NoticeBoard.Normal,
            expireTimeout: -1,
            transient: false,
            desktopEntry: "org.example.chat",
            image: "",
            hints: {},
            actions: [],
            closed: signal(),
            summaryChanged: signal(),
            bodyChanged: signal()
        }, properties);
        fake.expire = () => fake.closed.emit(NoticeBoard.Expired);
        fake.dismiss = () => fake.closed.emit(NoticeBoard.Dismissed);
        board.arrive(fake);
        return fake;
    }

    function test_the_panel_stands_at_the_trailing_edge_the_full_height_two_tile_units_wide_with_a_sheets_padding() {
        side.show(0);
        const panel = findChild(side, "panel");
        const contentWidth = 2 * Tokens.tileUnit + Tokens.spaceS;
        compare(panel.width, Geometry.hairline + 2 * Tokens.spaceM + contentWidth);
        compare(panel.x, 900 - panel.width, "at the trailing edge");
        compare(panel.y, 0);
        compare(panel.height, 640, "the full height");
        const pivot = findChild(side, "pivot");
        compare(pivot.mapToItem(panel, 0, 0).x, Geometry.hairline + Tokens.spaceM, "space-m at the sides");
        compare(pivot.y, Tokens.spaceL, "space-l at the top");
        compare(pivot.width, contentWidth);
        const scroller = findChild(side, "scroller");
        compare(scroller.width, contentWidth);
        compare(scroller.y + scroller.height, 640 - Tokens.spaceL, "and at the bottom");
        scene.height = 400;
        compare(panel.height, 400);
    }

    function test_the_panel_lies_on_the_ground_with_a_hairline_along_its_leading_edge_over_the_shading() {
        side.show(0);
        const panel = findChild(side, "panel");
        const ground = findChild(side, "ground");
        compare(panel.color, Tokens.color.textContrastLow, "the hairline shows under the ground");
        compare(ground.x, Geometry.hairline);
        compare(ground.width, panel.width - Geometry.hairline);
        compare(ground.color, Tokens.color.bg);
        const shading = findChild(side, "shading");
        compare(shading.color, Tokens.color.shading);
        compare(shading.width, 900, "over the whole of the rest");
        compare(shading.height, 640);
    }

    function test_its_pivot_is_a_places_strip_with_a_hairline_below() {
        side.show(0);
        const pivot = findChild(side, "pivot");
        compare(pivot.level, "nav");
        compare(pivot.titles, ["steuerung", "meldungen"]);
        compare(pivot.placeWidth, 2 * Tokens.tileUnit + Tokens.spaceS, "the panel is the place");
        verify(pivot.compact, "and a narrow one, so the strip takes the facet sizes");
        const under = findChild(side, "underPivot");
        compare(under.y, pivot.y + pivot.height);
        compare(under.width, pivot.width);
        compare(findChild(side, "scroller").y, under.y + Geometry.hairline);
    }

    function test_it_comes_all_the_way_in_from_the_trailing_edge_over_duration_moderate_with_ease_out_as_the_shading_fades_in() {
        Prefs.motion = "on";
        const comingIn = findChild(side, "comingIn");
        compare(comingIn.duration, Tokens.durationModerate);
        compare(comingIn.easing.type, Easing.Bezier);
        compare(comingIn.easing.bezierCurve, Tokens.easeOut);
        const shadingIn = findChild(side, "shadingIn");
        compare(shadingIn.duration, Tokens.durationModerate, "the shading over the same time");
        compare(shadingIn.easing.type, Easing.Linear, "linearly, as a sheet's");
        side.show(0);
        const panel = findChild(side, "panel");
        compare(panel.x, 900, "it starts wholly beyond the trailing edge");
        compare(findChild(side, "shading").opacity, 0);
        side.entry = 0.5;
        compare(panel.x, 900 - panel.width / 2, "it moves, never fades or scales");
        compare(panel.opacity, 1);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        tryCompare(side, "shade", 1, Tokens.durationModerate * 4);
        compare(panel.x, 900 - panel.width);
    }

    function test_it_leaves_the_way_it_came_in_0_8_duration_moderate_with_ease_out_and_is_closed_once_gone() {
        Prefs.motion = "on";
        const goingOut = findChild(side, "goingOut");
        compare(goingOut.duration, 0.8 * Tokens.durationModerate);
        compare(goingOut.easing.type, Easing.Bezier);
        compare(goingOut.easing.bezierCurve, Tokens.easeOut);
        const shadingOut = findChild(side, "shadingOut");
        compare(shadingOut.duration, 0.8 * Tokens.durationModerate);
        compare(shadingOut.easing.type, Easing.Linear);
        const closed = createTemporaryObject(spyComponent, testCase, { target: side, signalName: "closed" });
        side.show(0);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        side.close();
        verify(side.open, "it is open while it leaves");
        compare(closed.count, 0);
        tryCompare(closed, "count", 1, Tokens.durationModerate * 4);
        verify(!side.open);
        compare(side.entry, 0, "wholly beyond the trailing edge again");
        compare(side.shade, 0);
    }

    function test_shown_again_while_it_leaves_it_comes_back() {
        Prefs.motion = "on";
        side.show(0);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        side.close();
        side.show(0);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        wait(Tokens.durationModerate);
        verify(side.open, "it stays");
    }

    function test_under_reduced_motion_the_panel_and_the_shading_stand_at_once_and_go_at_once() {
        Prefs.motion = "off";
        side.show(0);
        compare(side.entry, 1, "in at once");
        compare(side.shade, 1);
        compare(findChild(side, "panel").x, 900 - side.panelWidth);
        side.close();
        verify(!side.open, "gone at once, never skipped");
        verify(!side.visible);
    }

    function test_escape_closes_it_and_the_focus_goes_back_to_where_it_was() {
        side.show(0);
        verify(!named("opener").activeFocus, "the panel holds the focus");
        keyClick(Qt.Key_Escape);
        verify(!side.open);
        verify(named("opener").activeFocus, "and gives it back");
    }

    function test_escape_closes_it_from_every_control() {
        for (const name of ["dark", "doNotDisturb", "powerProfile", "lock"]) {
            side.show(0);
            control(name).forceActiveFocus();
            keyClick(Qt.Key_Escape);
            verify(!side.open, name);
        }
    }

    function test_a_press_on_the_shading_closes_it_and_a_press_on_the_panel_does_not() {
        side.show(0);
        waitForRendering(side);
        mouseClick(side, 900 - side.panelWidth + 4, 600);
        verify(side.open, "the panel's ground");
        mouseClick(side, 900 - side.panelWidth - 4, 600);
        verify(!side.open, "the shading");
        verify(named("opener").activeFocus);
    }

    function test_nothing_behind_reacts_while_it_is_open() {
        const opener = named("opener");
        const clicked = createTemporaryObject(spyComponent, testCase, { target: opener, signalName: "clicked" });
        const behind = createTemporaryObject(scrollerBehindComponent, scene);
        mouseWheel(scene, 200, 300, 0, -120);
        tryVerify(() => behind.contentY > 0, 1000, "without the panel the wheel scrolls what lies behind");
        behind.cancelFlick();
        behind.contentY = 0;
        side.show(0);
        waitForRendering(side);
        mouseWheel(scene, 200, 300, 0, -120);
        wait(100);
        compare(behind.contentY, 0, "no wheel");
        mouseClick(opener);
        compare(clicked.count, 0, "no press: it lands on the shading");
    }

    function test_toggle_closes_it_on_the_facet_in_sight_and_turns_to_another() {
        side.toggle(0);
        verify(side.open);
        side.toggle(1);
        verify(side.open, "another facet");
        compare(side.currentIndex, 1);
        side.toggle(1);
        verify(!side.open, "the same facet");
    }

    function test_it_opens_on_the_facet_asked_for_without_sliding_it_in() {
        Prefs.motion = "on";
        side.show(1);
        compare(side.currentIndex, 1);
        verify(findChild(side, "messages").visible);
        verify(!controls.visible);
        compare(findChild(side, "shift").x, 0, "the facet stands");
        compare(findChild(side, "holder").opacity, 1);
    }

    function test_after_it_opened_on_a_facet_the_next_one_still_comes_from_the_trailing_edge_going_forward() {
        Prefs.motion = "on";
        side.show(0);
        side.show(1);
        side.close();
        tryCompare(side, "open", false, Tokens.durationModerate * 4);
        side.show(0);
        side.show(1);
        verify(findChild(side, "shift").x > 0, "forward, from the trailing edge");
    }

    function test_the_pivot_picks_steuerung_or_meldungen_and_their_facet_shows() {
        side.show(0);
        verify(controls.visible);
        verify(!findChild(side, "messages").visible);
        findChild(side, "pivot").forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(side.currentIndex, 1);
        verify(findChild(side, "messages").visible);
        verify(!controls.visible);
        keyClick(Qt.Key_Left);
        compare(side.currentIndex, 0);
        verify(controls.visible);
    }

    function test_focus_starts_at_the_first_control_and_on_an_empty_facet_at_the_pivot() {
        side.show(0);
        verify(control("dark").activeFocus, "the first control in steuerung");
        side.close();
        side.show(1);
        verify(findChild(side, "pivot").activeFocus, "meldungen has none yet");
    }

    function test_tab_and_the_arrows_reach_every_control_in_order() {
        side.show(0);
        const order = [control("dark"), control("doNotDisturb"), control("powerProfile"), control("lock")];
        for (let k = 1; k < order.length; k++) {
            keyClick(Qt.Key_Tab);
            verify(order[k].activeFocus, `Tab to ${order[k].objectName}`);
        }
        for (let k = order.length - 2; k >= 0; k--) {
            keyClick(Qt.Key_Tab, Qt.ShiftModifier);
            verify(order[k].activeFocus, `Shift+Tab to ${order[k].objectName}`);
        }
        keyClick(Qt.Key_Down);
        verify(order[1].activeFocus, "↓ to the next");
        keyClick(Qt.Key_Up);
        verify(order[0].activeFocus, "↑ to the one before");
        keyClick(Qt.Key_Up);
        verify(findChild(side, "pivot").activeFocus, "↑ from the first to the pivot");
        keyClick(Qt.Key_Down);
        verify(order[0].activeFocus, "↓ from the pivot to the first");
        order[3].forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(order[3].activeFocus, "the arrows never leave the panel");
    }

    function test_every_row_works_from_the_keyboard() {
        controls.hasPerformanceProfile = true;
        controls.kdeglobals = "";
        side.show(0);
        keyClick(Qt.Key_Space);
        compare(commands, [["plasma-apply-lookandfeel", "--apply", "org.kde.breezedark.desktop"]], "dunkel");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Space);
        verify(controls.doNotDisturb, "nicht stören");
        keyClick(Qt.Key_Down);
        verify(control("powerProfile").activeFocus);
        keyClick(Qt.Key_Right);
        compare(chosenProfiles, [2], "energieprofil, where the arrows choose");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        compare(commands[1], ["loginctl", "lock-session"], "sperren");
    }

    function test_dunkel_applies_the_dark_theme_of_plasmas_pair_and_the_light_one_back() {
        controls.kdeglobals = "[General]\nColorScheme=RektaLight\n\n[KDE]\nDefaultDarkLookAndFeel=org.example.night\nDefaultLightLookAndFeel=org.example.day\nLookAndFeelPackage=org.example.day\n";
        side.show(0);
        verify(!control("dark").checked, "light now");
        mouseClick(control("dark"));
        compare(commands, [["plasma-apply-lookandfeel", "--apply", "org.example.night"]]);
        mouseClick(control("dark"));
        compare(commands[1], ["plasma-apply-lookandfeel", "--apply", "org.example.day"]);
    }

    function test_without_a_pair_in_kdeglobals_dunkel_switches_between_breeze_and_breeze_dark() {
        compare(LookAndFeel.pair(""), { light: "org.kde.breeze.desktop", dark: "org.kde.breezedark.desktop" });
        compare(LookAndFeel.pair("[KDE]\nAnimationDurationFactor=0.5\n").dark, "org.kde.breezedark.desktop");
        compare(LookAndFeel.pair("[KDE][$i]\nDefaultDarkLookAndFeel[$i]=org.example.night\n").dark, "org.example.night", "KConfig flags");
        compare(LookAndFeel.pair("[Icons]\nDefaultDarkLookAndFeel=org.example.night\n").dark, "org.kde.breezedark.desktop", "only [KDE]");
        compare(LookAndFeel.pair("[KDE Action Restrictions]\nDefaultDarkLookAndFeel=org.example.night\n").dark, "org.kde.breezedark.desktop");
        compare(LookAndFeel.pair("[KDE]\nDefaultLightLookAndFeel = org.example.day\n").light, "org.example.day");
    }

    function test_dunkel_shows_the_systems_scheme_also_after_a_change_elsewhere() {
        Prefs.theme = "dark";
        const darkScene = createTemporaryObject(sceneComponent, testCase);
        verify(findChild(darkScene, "dark").checked, "dark from the start");
        darkScene.destroy();
        Prefs.theme = "light";
        side.show(0);
        Prefs.theme = "dark";
        verify(control("dark").checked);
        compare(findChild(control("dark"), "word").text, "an");
        mouseClick(control("dark"));
        verify(!control("dark").checked, "the choice shows at once");
        Prefs.theme = "light";
        Prefs.theme = "dark";
        verify(control("dark").checked, "and the system's next change too");
        Prefs.theme = "light";
        verify(!control("dark").checked);
        compare(findChild(control("dark"), "word").text, "aus");
    }

    function test_with_nicht_stoeren_only_critical_notifications_toast_and_the_others_go_quietly_into_the_list() {
        side.show(0);
        mouseClick(control("doNotDisturb"));
        verify(controls.doNotDisturb);
        notify({ summary: "anna" });
        compare(toaster.open, null, "no toast");
        compare(board.rows.length, 1, "but in the list");
        verify(board.rows[0].unseen);
        notify({ summary: "battery low", urgency: NoticeBoard.Critical });
        verify(toaster.open !== null, "a critical one toasts");
        compare(toaster.open.title, "battery low");
        mouseClick(control("doNotDisturb"));
        verify(!board.quiet, "off again");
    }

    function test_the_power_profile_segments_set_the_profile_and_offer_leistung_only_where_the_machine_has_it() {
        side.show(0);
        const segments = control("powerProfile");
        compare(segments.options, ["sparen", "ausgewogen"]);
        compare(segments.currentIndex, 1, "balanced");
        controls.hasPerformanceProfile = true;
        compare(segments.options, ["sparen", "ausgewogen", "leistung"]);
        segments.forceActiveFocus();
        keyClick(Qt.Key_Left);
        compare(chosenProfiles, [0]);
        controls.powerProfile = 2;
        compare(segments.currentIndex, 2, "a profile set elsewhere shows");
    }

    function test_without_the_power_profile_daemon_its_row_is_gone() {
        side.show(0);
        verify(rowOf(control("powerProfile")).visible);
        controls.hasPowerProfiles = false;
        verify(!rowOf(control("powerProfile")).visible);
        verify(findChild(controls, "session").visible, "sperren still stands in sitzung");
    }

    function test_sperren_locks_the_session() {
        side.show(0);
        waitForRendering(side);
        mouseClick(control("lock"));
        compare(commands, [["loginctl", "lock-session"]]);
    }

    function test_the_groups_stand_in_order_with_headings_and_a_group_without_rows_falls_away() {
        side.show(0);
        const groups = ["sound", "connections", "display", "session"].map(name => findChild(controls, name));
        verify(!groups[0].visible, "ton has no rows yet");
        verify(!groups[1].visible, "nor verbindungen");
        verify(groups[2].visible);
        verify(groups[3].visible);
        compare(findChild(groups[2], "heading").text, "anzeige");
        compare(findChild(groups[3], "heading").text, "sitzung");
        tryCompare(groups[2], "y", 0, 1000, "the first in sight at the top");
        verify(!findChild(groups[2], "between").visible, "with no group before it");
        verify(groups[3].y > groups[2].y);
        verify(findChild(groups[3], "between").visible, "a hairline between the two");
    }

    function test_a_group_whose_rows_are_all_absent_falls_away() {
        const group = createTemporaryObject(absentGroupComponent, testCase);
        verify(!group.visible);
        group.rows[0].present = true;
        verify(group.visible);
    }

    function test_a_group_takes_space_l_above_and_below_and_its_heading_stands_space_m_above_its_rows() {
        side.show(0);
        const group = findChild(controls, "display");
        const heading = findChild(group, "heading");
        const rows = findChild(group, "rows");
        waitForRendering(side);
        compare(heading.mapToItem(group, 0, 0).y, Tokens.spaceL);
        compare(rows.mapToItem(group, 0, 0).y, Tokens.spaceL + heading.height + Tokens.spaceM);
        compare(group.height, 2 * Tokens.spaceL + heading.height + Tokens.spaceM + rows.height + Geometry.hairline, "the last row's line below");
    }

    function test_a_row_has_its_words_at_the_start_and_its_control_at_the_end_on_a_hairline() {
        side.show(0);
        const toggle = control("dark");
        const row = rowOf(toggle);
        waitForRendering(side);
        const words = findChild(row, "words");
        compare(words.text, "dunkel");
        compare(words.x, 0);
        compare(findChild(row, "holder").x, row.width - toggle.implicitWidth, "the control at the end");
        compare(row.height, Geometry.hairline + 2 * Tokens.spaceS + Math.max(words.height, toggle.implicitHeight), "space-s above and below");
        compare(row.children[0].color, Tokens.color.textContrastLow, "on a hairline");
        compare(findChild(rowOf(control("lock")), "holder").x, 0, "a row without words has its control at the start");
    }

    function test_a_row_whose_words_and_control_do_not_fit_puts_the_control_below_and_cuts_long_words() {
        side.show(0);
        const toggle = control("dark");
        const row = rowOf(toggle);
        row.label = "a long word for the dark look that cannot share its line with the toggle";
        waitForRendering(side);
        const words = findChild(row, "words");
        compare(findChild(row, "holder").x, 0);
        compare(findChild(row, "holder").y, Geometry.hairline + Tokens.spaceS + words.height, "below the words");
        compare(words.width, row.width);
        verify(words.truncated, "the words are cut, not wrapped");
        compare(words.lineCount, 1);
    }

    function test_the_toggles_are_named_by_their_rows() {
        compare(control("dark").Accessible.name, "dunkel");
        compare(control("doNotDisturb").Accessible.name, "nicht stören");
    }

    // The panel follows the one current theme and density, so the contact sheet is drawn once per pair.
    function test_contact_sheet_of_the_panel_in_both_themes_and_densities() {
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const contact = createTemporaryObject(contactComponent, testCase);
                const panel = findChild(contact, "panel");
                panel.controls.hasPerformanceProfile = true;
                panel.show(0);
                waitForRendering(contact);
                grabImage(contact).save(`panel-sheet-${theme}-${density}.png`);
                verify(panel.open, `${theme} ${density}`);
                contact.destroy();
            }
        }
    }
}
