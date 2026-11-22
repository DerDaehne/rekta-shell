pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets

// The tile that opens an area of a side panel: its parts, its words cut to one line, no pressed state and no accent,
// a status fill only for a status, how it reads, and its two widths in a panel's compact grid.
TestCase {
    id: testCase

    name: "OpenerTile"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 720

    // As wide as the side panel's content, so a unit is half of it; a tooltip host, as the panel is.
    Component {
        id: gridComponent

        Rectangle {
            readonly property bool overflowTips: true
            property alias grid: tiles

            width: tiles.width + 2 * Tokens.spaceM
            height: tiles.height + 2 * Tokens.spaceM
            color: Tokens.color.bg

            TileGrid {
                id: tiles

                x: Tokens.spaceM
                y: Tokens.spaceM
                width: 2.5 * Tokens.tileUnit + Tokens.spaceS
                placeWidth: width
                viewportHeight: 1000

                OpenerTile {
                    objectName: "bluetooth"
                    glyph: "bluetooth"
                    name: "bluetooth"
                    stateWord: "aus"
                }

                OpenerTile {
                    objectName: "sound"
                    glyph: "speaker"
                    name: "ton"
                    stateWord: "Speakers"
                }

                OpenerTile {
                    objectName: "network"
                    columns: 2
                    glyph: "wireless"
                    name: "netz"
                    stateWord: "Home"
                }

                OpenerTile {
                    objectName: "long"
                    glyph: "speaker"
                    name: "ausgang und eingang aller geräte im raum"
                    stateWord: "Navi 21/23 HDMI/DP Audio Controller Digital Stereo"
                }

                OpenerTile {
                    objectName: "failed"
                    glyph: "wireless"
                    name: "netz"
                    stateWord: "fehlgeschlagen"
                    status: "error"
                }

                OpenerTile {
                    objectName: "session"
                    glyph: "user"
                    name: "sitzung"
                    stateWord: "rekta"
                }
            }
        }
    }

    Component {
        id: spy

        SignalSpy {
            signalName: "activated"
        }
    }

    // The default accent is ink and on-accent the ground; here both have a colour of their own, so an accent would show.
    property color accentLight
    property color onAccentLight
    property var host

    function initTestCase() {
        accentLight = Tokens.light.accent;
        onAccentLight = Tokens.light.textOnAccent;
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.theme = "light";
        Prefs.motion = "off";
        Tokens.light.accent = "#1f5fd1";
        Tokens.light.textOnAccent = "#fffbe0";
        host = createTemporaryObject(gridComponent, testCase);
        waitForRendering(host);
    }

    function cleanup() {
        Tips.hide();
        Tokens.light.accent = accentLight;
        Tokens.light.textOnAccent = onAccentLight;
        Prefs.theme = "system";
        Prefs.motion = "system";
    }

    function tile(name: string): var {
        return findChild(host, name);
    }

    function fillOf(name: string): color {
        return findChild(tile(name), "fill").color;
    }

    function test_its_icon_stands_at_the_top_leading_corner_its_name_at_the_foot_and_its_state_word_right_under_it() {
        const opener = tile("bluetooth");
        const icon = findChild(opener, "glyph");
        compare(icon.name, "bluetooth");
        compare(icon.size, Tokens.tileIcon);
        compare(icon.x, Geometry.tilePadding);
        compare(icon.y, Geometry.tilePadding);
        const name = findChild(opener, "name");
        const state = findChild(opener, "state");
        compare(name.text, "bluetooth");
        compare(state.text, "aus");
        const nameAt = name.mapToItem(opener, 0, 0);
        const stateAt = state.mapToItem(opener, 0, 0);
        compare(nameAt.x, Geometry.tilePadding, "at the leading edge");
        compare(stateAt.x, Geometry.tilePadding);
        compare(stateAt.y, nameAt.y + name.height, "the state word right under the name, no gap");
        compare(stateAt.y + state.height, opener.height - Geometry.tilePadding, "at the foot, inside the padding");
        compare(name.font.weight, Tokens.fontWeightSemibold, "the name in semibold");
        compare(state.font.weight, Tokens.fontWeightRegular);
        for (const words of [name, state]) {
            compare(words.font.pixelSize, Tokens.fontSizeXs, `${words.text}: the tile's type`);
            compare(words.lineHeight, Tokens.lineHeightCompact * Tokens.fontSizeXs);
            compare(words.color, Tokens.color.textPrimary);
        }
        verify(!findChild(opener, "chevron"), "no chevron: its press says that it opens");
    }

    function test_a_long_name_and_state_word_are_each_cut_to_one_line_and_show_whole_in_their_tip() {
        const opener = tile("long");
        const name = findChild(opener, "name");
        const state = findChild(opener, "state");
        for (const words of [name, state]) {
            verify(words.truncated, `${words.text}: cut`);
            compare(words.lineCount, 1, `${words.text}: one line`);
            compare(words.elide, Text.ElideRight, "with an ellipsis");
            compare(words.width, opener.width - 2 * Geometry.tilePadding, `${words.text}: within the padding`);
        }
        mouseMove(host, 1, 1);
        Tips.hiddenAt = Date.now();
        mouseMove(state);
        compare(Tips.target, state);
        compare(Tips.text, "Navi 21/23 HDMI/DP Audio Controller Digital Stereo", "the whole state word");
        verify(!findChild(tile("bluetooth"), "name").truncated, "a short name stays whole");
    }

    function test_pressed_it_gives_way_as_a_tile_that_opens_and_takes_no_accent_and_no_pressed_state() {
        const opener = tile("bluetooth");
        verify(opener.opens);
        compare(fillOf("bluetooth"), Tokens.color.surface, "neutral");
        mousePress(opener, opener.width / 2, opener.height / 2);
        tryCompare(opener, "sink", 1, Tokens.durationPress * 4);
        verify(opener.pressScale < 1, "it sinks as every tile that opens");
        compare(fillOf("bluetooth"), Tokens.color.surface, "no accent fill while pressed");
        verify(!Qt.colorEqual(fillOf("bluetooth"), Tokens.color.accent));
        verify(!opener.Accessible.checkable, "no pressed state to read");
        verify(!opener.Accessible.checked);
        const activations = createTemporaryObject(spy, testCase, { target: opener });
        mouseRelease(opener, opener.width / 2, opener.height / 2);
        compare(activations.count, 1, "a press opens");
        compare(fillOf("bluetooth"), Tokens.color.surface, "and it stays neutral");
    }

    function test_it_takes_a_status_fill_and_word_only_with_a_status() {
        for (const name of ["bluetooth", "sound", "network", "long", "session"])
            compare(fillOf(name), Tokens.color.surface, `${name}: neutral`);
        compare(fillOf("failed"), Tokens.color.statusErrorTile);
        compare(findChild(tile("failed"), "word").text, "failed", "and its status word");
        verify(!findChild(tile("bluetooth"), "word").visible);
        tile("failed").status = "";
        compare(fillOf("failed"), Tokens.color.surface, "without it, neutral again");
    }

    function test_it_reads_as_a_button_named_by_its_name_then_its_state() {
        const opener = tile("bluetooth");
        compare(opener.Accessible.role, Accessible.Button);
        compare(opener.Accessible.name, "bluetooth, aus");
        compare(tile("network").Accessible.name, "netz, Home");
        opener.stateWord = "an";
        compare(opener.Accessible.name, "bluetooth, an", "it follows the state");
    }

    function test_in_a_panels_compact_grid_one_unit_is_half_its_width_and_two_units_its_whole_width() {
        const grid = host.grid;
        const half = (grid.width - Tokens.spaceS) / 2;
        compare(tile("bluetooth").width, half);
        compare(tile("bluetooth").height, Tokens.tileUnit, "one unit high");
        compare(tile("sound").x, half + Tokens.spaceS, "two across, space-s apart");
        compare(tile("network").width, grid.width, "two units: the whole width");
        compare(tile("network").height, Tokens.tileUnit);
        compare(tile("network").y, Tokens.tileUnit + Tokens.spaceS, "on a row of its own");
    }

    function test_contact_sheet_of_opener_tiles_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(gridComponent, testCase);
            findChild(findChild(sheet, "sound"), "press").start(0.9, 0.9);
            findChild(sheet, "session").forceActiveFocus();
            wait(Tokens.durationPress + Tokens.durationShort);
            grabImage(sheet).save(`opener-tile-sheet-${theme}.png`);
            verify(findChild(sheet, "session").activeFocus, theme);
        }
    }
}
