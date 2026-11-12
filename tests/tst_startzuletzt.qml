pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Panel
import Rekta
import RektaShell.DBus
import Start
import "ContactSheets.js" as ContactSheets

// "zuletzt" in the start place: the files used last, as rows that open them; live changes, holding still, the empty and
// the failed state, the switch, the keys and the turn. The activity manager is a name owned on the test's private bus,
// and Kickoff's model a stand-in that holds what a test puts in.
TestCase {
    id: testCase

    name: "StartZuletzt"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1920
    height: 1080

    // What the Start was asked to open, oldest first.
    property var calls: []
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var start
    property var recent
    property var owner
    // The time the files are used against; the rows tell it against `clock`.
    property double base: new Date(2026, 10, 12, 18, 0).getTime()

    Component {
        id: sceneComponent

        Item {
            id: scene

            property bool showRecent: true

            StartPlace {
                objectName: "start"
                width: scene.width
                height: scene.height
                showRecent: scene.showRecent
                pinned: [testCase.fakeApp("systemsettings", 1), testCase.fakeApp("dolphin", 2)]
                openUrl: url => {
                    testCase.calls = [...testCase.calls, `open ${url}`];
                }
            }
        }
    }

    // KDE's activity manager, as far as "zuletzt" asks for it: its name on the bus.
    Component {
        id: ownerComponent

        DBusConnection {
            Component.onCompleted: own("org.kde.ActivityManager", "/ActivityManager", `<interface name="org.kde.ActivityManager"><method name="Ping"/></interface>`)
        }
    }

    // A light and a dark window behind the glass.
    Component {
        id: backdropComponent

        Item {
            Rectangle {
                width: parent.width / 2
                height: parent.height
                color: "white"
            }

            Rectangle {
                x: parent.width / 2
                width: parent.width / 2
                height: parent.height
                color: "black"
            }
        }
    }

    function fakeApp(name: string, columns: int): var {
        return {
            id: name,
            name: name,
            icon: "",
            columns: columns,
            rows: 1,
            launch: () => {}
        };
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "system";
        calls = [];
        owner = createTemporaryObject(ownerComponent, testCase);
        makeScene(testCase, testCase.width, testCase.height, true);
    }

    function cleanup() {
        // A pointer left over from a test would hover what appears under it next.
        mouseMove(testCase, 1, 1);
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function makeScene(parent: Item, width: real, height: real, shown: bool): Item {
        const scene = createTemporaryObject(sceneComponent, parent, {
            width: width,
            height: height,
            showRecent: shown
        });
        start = findChild(scene, "start");
        recent = findChild(start, "zuletzt");
        recent.clock = () => new Date(testCase.base);
        recent.now = recent.clock();
        if (shown)
            tryVerify(() => recent.source !== null, 2000, "the activity manager answers and the model is made");
        return scene;
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    // Opens the Start without motion, as a reduced-motion user sees it at once, once the rows that came have settled.
    function openNow() {
        wait(Tokens.durationModerate);
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "system";
        waitForRendering(start);
    }

    // A file used `minutesAgo` before `base`: it goes to the top of the model, as kactivitymanagerd moves it.
    function use(name: string, minutesAgo: real, icon: string) {
        const model = recent.source;
        const url = `file:///beispiel/dokumente/${name}`;
        for (let k = 0; k < model.count; k++) {
            if (model.get(k).url === url) {
                model.setProperty(k, "modified", (base - minutesAgo * 60000) / 1000);
                model.move(k, 0, 1);
                settle();
                return;
            }
        }
        model.insert(0, {
            display: name,
            decoration: icon ?? "",
            description: "Persönlicher Ordner/Dokumente",
            url: url,
            modified: (base - minutesAgo * 60000) / 1000
        });
        settle();
    }

    // The rows follow the model a moment later, as Qt.callLater runs, and stand once laid out.
    function settle() {
        wait(1);
        waitForItemPolished(recent);
    }

    // Three files, the newest first: c.pdf, b.pdf, a.pdf.
    function three() {
        use("a.pdf", 30);
        use("b.pdf", 20);
        use("c.pdf", 4, "application-pdf");
    }

    // The rows in "zuletzt", from the top, leaving ones too.
    function rows(): var {
        return findChild(recent, "recentRows").children.filter(child => child instanceof MessageRow);
    }

    function inPlace(): var {
        return rows().filter(row => !row.going).map(row => row.summary);
    }

    function test_zuletzt_stands_after_heute_two_units_wide_with_its_title_last_in_the_strip() {
        openNow();
        const section = named("recent");
        const today = named("today");
        compare(named("sectionStrip").titles, ["angeheftet", "heute", "zuletzt"]);
        verify(section.visible);
        compare(section.width, 2 * start.unitStep);
        compare(section.x, today.x + today.width + named("panorama").gap);
        compare(findChild(section, "heading").text, "zuletzt");
        compare(section.verticalInset, today.verticalInset);
        compare(section.headingSpacing, today.headingSpacing);
        compare(section.headingToken, today.headingToken);
    }

    function test_angeheftet_with_many_tiles_widens_only_as_far_as_zuletzt_stays_in_view() {
        makeScene(testCase, 1920, 900, true);
        start.pinned = Array.from({
            length: 60
        }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        const section = named("recent");
        verify(named("pinned").width > 4 * start.unitStep, "angeheftet widens");
        verify(section.x + section.width <= 1920 - Tokens.spaceXl, `${section.x + section.width} past the inset`);
        verify(named("panorama").fit);
    }

    function test_with_a_window_open_at_1920_by_1080_the_panorama_runs_past_the_window_and_scrolls_sideways() {
        start.windows = [{
                appId: "org.kde.konsole",
                title: "konsole",
                icon: "",
                lastActivated: 1,
                stackingOrder: 0,
                active: false,
                minimized: false,
                activate: () => {}
            }];
        openNow();
        compare(named("sectionStrip").titles, ["läuft", "angeheftet", "heute", "zuletzt"]);
        verify(!named("panorama").fit);
        compare(start.pinnedUnits, 4);
    }

    function test_at_1600_where_zuletzt_does_not_fit_beside_angeheftet_it_keeps_four_units() {
        makeScene(testCase, 1600, 900, true);
        start.pinned = Array.from({
            length: 40
        }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        compare(start.pinnedUnits, 4);
    }

    function test_the_files_used_last_stand_newest_first_with_icon_name_folder_and_time() {
        three();
        openNow();
        compare(inPlace(), ["c.pdf", "b.pdf", "a.pdf"]);
        const first = rows()[0];
        compare(findChild(first, "summary").text, "c.pdf");
        compare(findChild(first, "body").text, "Persönlicher Ordner/Dokumente");
        compare(findChild(first, "time").text, "vor 4 min");
        compare(findChild(rows()[2], "time").text, "vor 30 min");
        compare(findChild(first, "icon").source.toString(), "image://icon/application-pdf");
    }

    function test_at_most_ten_files_stand() {
        for (let k = 0; k < 12; k++)
            use(`${k}.txt`, 60 - k);
        openNow();
        compare(inPlace().length, 10);
        compare(inPlace()[0], "11.txt");
        compare(inPlace()[9], "2.txt");
    }

    function test_a_press_opens_the_file_and_the_start_turns_out_forward() {
        three();
        openNow();
        mouseClick(rows()[1]);
        compare(calls, ["open file:///beispiel/dokumente/b.pdf"]);
        compare(start.phase, "closing");
        verify(!start.holdsKeyboard || start.returnTo === null, "forward: no window gets the keyboard back");
    }

    function test_enter_and_space_open_the_focused_file() {
        three();
        openNow();
        rows()[0].forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(calls, ["open file:///beispiel/dokumente/c.pdf"]);
        start.close(null);
        tryCompare(start, "phase", "closed", 4000);
        openNow();
        rows()[2].forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(calls[1], "open file:///beispiel/dokumente/a.pdf");
    }

    function test_a_file_used_anew_enters_at_the_top_and_the_eleventh_leaves() {
        for (let k = 0; k < 10; k++)
            use(`${k}.txt`, 60 - k);
        openNow();
        const oldest = rows()[9];
        compare(oldest.summary, "0.txt");
        use("new.txt", 0);
        compare(rows()[0].summary, "new.txt");
        verify(oldest.going, "the eleventh drifts out");
        tryVerify(() => rows().length === 10, Tokens.durationShort * 4, "then it has gone");
        compare(inPlace()[9], "1.txt");
    }

    function test_a_file_used_again_moves_to_the_top_keeping_its_row() {
        three();
        openNow();
        const a = rows()[2];
        use("a.pdf", 0);
        compare(inPlace(), ["a.pdf", "c.pdf", "b.pdf"]);
        verify(rows().includes(a));
        compare(findChild(a, "time").text, "gerade eben");
    }

    function test_under_the_pointer_zuletzt_holds_still_and_counts_the_waiting_updates() {
        three();
        openNow();
        mouseMove(rows()[1]);
        use("d.pdf", 0);
        wait(Tokens.durationShort);
        compare(inPlace(), ["c.pdf", "b.pdf", "a.pdf"]);
        const more = findChild(recent, "waiting");
        verify(more.visible);
        compare(more.Accessible.name, "1 aktualisierung wartet · zeigen");
        use("a.pdf", 0);
        compare(more.count, 2, "a file used anew is an update of its own");
        mouseMove(testCase, 1, 1);
        compare(inPlace(), ["a.pdf", "d.pdf", "c.pdf", "b.pdf"]);
        verify(!more.visible);
    }

    function test_pressing_the_waiting_button_shows_the_updates_while_zuletzt_stays_held() {
        three();
        openNow();
        mouseMove(rows()[1]);
        use("d.pdf", 0);
        mouseClick(findChild(recent, "waiting"));
        verify(recent.held);
        compare(inPlace(), ["d.pdf", "c.pdf", "b.pdf", "a.pdf"]);
        compare(calls, [], "the button opens nothing");
    }

    function test_with_the_focus_in_it_zuletzt_holds_still_until_it_leaves() {
        three();
        openNow();
        rows()[1].forceActiveFocus();
        use("d.pdf", 0);
        compare(inPlace(), ["c.pdf", "b.pdf", "a.pdf"]);
        named("pivot").forceActiveFocus();
        compare(inPlace(), ["d.pdf", "c.pdf", "b.pdf", "a.pdf"]);
    }

    function test_a_new_row_slides_in_over_duration_short() {
        three();
        openNow();
        use("d.pdf", 0);
        const d = rows()[0];
        tryVerify(() => d.opacity > 0 && d.opacity < 1, Tokens.durationShort, "it fades up");
        tryCompare(d, "opacity", 1, Tokens.durationShort * 4);
    }

    function test_under_reduced_motion_a_new_file_stands_at_once() {
        three();
        openNow();
        Prefs.motion = "off";
        use("d.pdf", 0);
        compare(rows()[0].summary, "d.pdf");
        compare(rows()[0].opacity, 1);
    }

    function test_with_no_file_used_zuletzt_stays_and_says_so() {
        openNow();
        const empty = findChild(recent, "recentEmpty");
        verify(empty.visible);
        compare(empty.text, "noch keine datei geöffnet.");
        verify(!empty.failed);
        verify(named("recent").visible);
        use("a.pdf", 1);
        verify(!empty.visible);
    }

    function test_without_the_activity_manager_zuletzt_says_why_with_a_retry_and_reads_nothing() {
        owner.destroy();
        tryVerify(() => {
            recent.check();
            return recent.service === "down";
        }, 3000);
        openNow();
        const failed = findChild(recent, "recentFailed");
        verify(failed.visible);
        verify(failed.failed);
        compare(failed.text, "zuletzt geöffnete dateien lassen sich nicht laden: der dienst von kde, der sie sich merkt, läuft nicht. eine neue anmeldung startet ihn.");
        compare(findChild(failed, "sentence").color, Tokens.color.textPrimary);
        verify(findChild(failed, "errorMark").visible);
        compare(findChild(failed, "errorMark").color, Tokens.color.statusErrorFull);
        compare(findChild(failed, "retry").text, "neu laden");
        verify(!findChild(recent, "recentEmpty").visible);
        compare(recent.source, null, "no model reads the files used");
        compare(rows().length, 0);
    }

    function test_the_retry_asks_the_activity_manager_again() {
        owner.destroy();
        tryVerify(() => {
            recent.check();
            return recent.service === "down";
        }, 3000);
        openNow();
        owner = createTemporaryObject(ownerComponent, testCase);
        tryVerify(() => {
            mouseClick(findChild(recent, "retry"));
            return recent.service === "up";
        }, 3000);
        verify(!findChild(recent, "recentFailed").visible);
        verify(findChild(recent, "recentEmpty").visible);
    }

    function test_each_opening_of_the_start_asks_the_activity_manager_again() {
        openNow();
        compare(recent.service, "up");
        start.close(null);
        tryCompare(start, "phase", "closed", 4000);
        owner.destroy();
        wait(200);
        openNow();
        tryCompare(recent, "service", "down", 3000);
    }

    function test_switched_off_zuletzt_has_no_section_no_title_and_no_model() {
        makeScene(testCase, testCase.width, testCase.height, false);
        openNow();
        verify(named("recent") !== null, "kept, but out of the panorama");
        verify(!named("panorama").sectionItems().includes(named("recent")));
        compare(named("recent").parent, null);
        verify(named("panorama").fit, "it takes no room");
        compare(named("sectionStrip").titles, ["angeheftet", "heute"]);
        wait(100);
        compare(recent.source, null);
    }

    function test_switched_off_while_the_shell_runs_zuletzt_lets_go_of_its_model_and_its_title() {
        use("a.pdf", 1);
        start.showRecent = false;
        compare(recent.source, null);
        compare(named("sectionStrip").titles, ["angeheftet", "heute"]);
        start.showRecent = true;
        tryVerify(() => recent.source !== null, 2000, "on again, it asks and reads anew");
    }

    function test_a_row_has_no_remove_button_and_delete_and_a_pull_remove_nothing() {
        three();
        openNow();
        const row = rows()[0];
        verify(!findChild(row, "remove").visible);
        row.forceActiveFocus();
        keyClick(Qt.Key_Delete);
        verify(!findChild(row, "pull").enabled);
        compare(inPlace(), ["c.pdf", "b.pdf", "a.pdf"]);
        compare(recent.source.count, 3);
    }

    function test_the_arrows_go_from_heute_to_each_row() {
        three();
        openNow();
        const empty = findChild(named("today"), "todayEmpty");
        verify(empty.visible);
        const pinnedTiles = findChild(named("pinned"), "grid").children.filter(item => (item as Tile) !== null);
        pinnedTiles[pinnedTiles.length - 1].forceActiveFocus();
        keyClick(Qt.Key_Right);
        verify(rows()[0].activeFocus, "right from angeheftet past an empty heute");
        keyClick(Qt.Key_Down);
        verify(rows()[1].activeFocus);
        keyClick(Qt.Key_Down);
        verify(rows()[2].activeFocus);
        keyClick(Qt.Key_Up);
        verify(rows()[1].activeFocus);
    }

    function test_each_row_is_named_by_file_folder_and_time() {
        three();
        openNow();
        compare(rows()[0].Accessible.name, "c.pdf, Persönlicher Ordner/Dokumente, vor 4 min");
        compare(rows()[0].Accessible.role, Accessible.Button);
    }

    function test_rows_that_do_not_fit_scroll_within_the_section_to_the_focus() {
        makeScene(testCase, 1920, 600, true);
        for (let k = 0; k < 10; k++)
            use(`${k}.txt`, 60 - k);
        openNow();
        const section = named("recent");
        verify(section.contentHeight > section.height, "ten rows are taller than the section");
        rows()[9].forceActiveFocus();
        tryVerify(() => section.contentY > 0, 2000, "the section scrolls to the last row");
        const at = rows()[9].mapToItem(section, 0, 0);
        verify(at.y + rows()[9].height <= section.height + 1, `${at.y} below the section`);
    }

    function test_the_rows_turn_in_with_the_start_as_parts_of_its_turn() {
        three();
        openNow();
        const parts = findChild(start, "turn").partsOf(named("body")).map(part => part.item);
        for (const row of rows())
            verify(parts.includes(row), row.summary);
    }

    function test_contact_sheets_of_zuletzt_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase, {
                width: testCase.width,
                height: testCase.height
            });
            makeScene(backdrop, testCase.width, testCase.height, true);
            use("quartalsbericht-entwurf-mit-anmerkungen.odt", 600);
            use("urlaub-2026.jpg", 95);
            use("rechnung-0815.pdf", 12);
            use("notizen.md", 0);
            openNow();
            wait(Tokens.durationShort);
            grabImage(backdrop).save(`start-zuletzt-${theme}.png`);
            verify(start.wanted, theme);
        }
    }
}
