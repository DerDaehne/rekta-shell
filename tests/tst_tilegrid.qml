pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "TileGrid"
    visible: true
    when: windowShown
    width: 1000
    height: 600

    // A wide tile, a tall one, then small ones: the small ones fill what the bigger ones leave.
    Component {
        id: gridComponent

        TileGrid {
            columns: 3

            Tile { objectName: "wide"; columns: 2 }
            Tile { objectName: "tall"; rows: 2 }
            Tile { objectName: "small1" }
            Tile { objectName: "small2" }
            Tile { objectName: "hidden"; visible: false }
            Tile { objectName: "small3" }
        }
    }

    // Two wide tiles and a small one: the second wide one leaves a hole at the end of the first row.
    Component {
        id: holeComponent

        TileGrid {
            columns: 3

            Tile { objectName: "first"; columns: 2 }
            Tile { objectName: "second"; columns: 2 }
            Tile { objectName: "small" }
        }
    }

    // In a compact place: 700 px wide, the viewport tall enough.
    Component {
        id: compactComponent

        TileGrid {
            columns: 4
            placeWidth: 700
            viewportHeight: 900

            Tile { objectName: "wide"; columns: 2 }
            Tile { objectName: "small1" }
            Tile { objectName: "big"; columns: 2; rows: 2 }
            Tile { objectName: "small2" }
        }
    }

    // A side panel's grid of opener tiles, one tab stop between a control before it and one after: two across, a wide
    // tile on the third row (| ton | netz | over | bluetooth wide | over | anzeige | sitzung |).
    Component {
        id: oneStopComponent

        Column {
            property alias grid: openers

            Button {
                objectName: "before"
                text: "dunkel"
            }

            TileGrid {
                id: openers

                width: 2.5 * Tokens.tileUnit + Tokens.spaceS
                placeWidth: width
                viewportHeight: 900
                oneTabStop: true

                OpenerTile { objectName: "ton"; name: "ton" }
                OpenerTile { objectName: "netz"; name: "netz" }
                OpenerTile { objectName: "bluetooth"; name: "bluetooth"; columns: 2 }
                OpenerTile { objectName: "anzeige"; name: "anzeige" }
                OpenerTile { objectName: "sitzung"; name: "sitzung" }
            }

            Button {
                objectName: "after"
                text: "sperren"
            }
        }
    }

    property TileGrid grid

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        grid = createTemporaryObject(gridComponent, testCase);
    }

    function cellOf(name: string): point {
        const tile = findChild(grid, name);
        const step = Tokens.tileUnit + Tokens.spaceS;
        return Qt.point(tile.x / step, tile.y / step);
    }

    function test_tiles_take_the_first_free_cells_row_by_row() {
        compare(cellOf("wide"), Qt.point(0, 0));
        compare(cellOf("tall"), Qt.point(2, 0));
        compare(cellOf("small1"), Qt.point(0, 1));
        compare(cellOf("small2"), Qt.point(1, 1));
    }

    function test_a_tile_that_grows_moves_the_ones_after_it_on() {
        findChild(grid, "small1").columns = 2;
        compare(cellOf("small1"), Qt.point(0, 1), "two units still fit beside the tall tile");
        compare(cellOf("small2"), Qt.point(0, 2));
        compare(cellOf("small3"), Qt.point(1, 2), "the next free cell after small2");
    }

    function test_a_small_tile_after_two_wide_ones_fills_the_hole_in_the_first_row() {
        grid = createTemporaryObject(holeComponent, testCase);
        compare(cellOf("second"), Qt.point(0, 1));
        compare(cellOf("small"), Qt.point(2, 0));
        compare(grid.rows, 2);
    }

    function test_cells_are_a_tile_unit_with_space_s_between() {
        const small2 = findChild(grid, "small2");
        compare(small2.x, Tokens.tileUnit + Tokens.spaceS);
        compare(small2.y, Tokens.tileUnit + Tokens.spaceS);
    }

    function test_a_hidden_tile_takes_no_cell() {
        compare(cellOf("small3"), Qt.point(0, 2));
        findChild(grid, "hidden").visible = true;
        compare(cellOf("hidden"), Qt.point(0, 2));
        compare(cellOf("small3"), Qt.point(1, 2));
    }

    function test_the_grid_is_as_wide_as_its_columns_and_as_tall_as_its_rows() {
        compare(grid.implicitWidth, 3 * Tokens.tileUnit + 2 * Tokens.spaceS);
        compare(grid.rows, 3);
        compare(grid.implicitHeight, 3 * Tokens.tileUnit + 2 * Tokens.spaceS);
    }

    function test_sideways_the_cells_stay_a_tile_unit_however_wide_the_grid_is() {
        grid.width = 900;
        verify(!grid.stretched);
        compare(grid.across, 3);
        compare(findChild(grid, "small1").width, Tokens.tileUnit);
        compare(findChild(grid, "wide").width, 2 * Tokens.tileUnit + Tokens.spaceS);
    }

    function test_sideways_a_grid_without_columns_sets_its_tiles_in_one_column() {
        for (const columns of [0, -2]) {
            grid.columns = columns;
            compare(grid.across, 1, `${columns} columns`);
            compare(cellOf("wide"), Qt.point(0, 0), "wider than the grid, it still takes the first column");
            compare(cellOf("tall"), Qt.point(0, 1));
            compare(cellOf("small3"), Qt.point(0, 5));
            compare(grid.rows, 6);
        }
    }

    function test_a_compact_grid_without_columns_turning_sideways_sets_its_tiles_in_one_column() {
        grid = createTemporaryObject(compactComponent, testCase, {
            width: 600,
            columns: 0
        });
        compare(grid.across, 3);
        grid.placeWidth = 1600;
        verify(!grid.stretched);
        compare(grid.across, 1);
        compare(cellOf("big"), Qt.point(0, 2));
        compare(cellOf("small2"), Qt.point(0, 4));
        compare(findChild(grid, "small2").width, Tokens.tileUnit);
    }

    // Compact

    function test_compact_a_grid_has_as_many_tile_unit_columns_as_fit_its_width_stretched_to_fill_it() {
        grid = createTemporaryObject(compactComponent, testCase, {
            width: 600
        });
        verify(grid.stretched);
        compare(grid.across, 3, "three units and their gaps fit in 600 px, four do not");
        const cell = (600 - 2 * Tokens.spaceS) / 3;
        compare(grid.cellWidth, cell);
        const small1 = findChild(grid, "small1");
        compare(Qt.rect(small1.x, small1.y, small1.width, small1.height), Qt.rect(2 * (cell + Tokens.spaceS), 0, cell, Tokens.tileUnit));
        compare(small1.x + small1.width, 600, "the row is full");
    }

    function test_compact_a_grid_narrower_than_two_units_still_has_two_columns_each_half_of_it() {
        grid = createTemporaryObject(compactComponent, testCase, {
            width: 300
        });
        compare(grid.across, 2);
        compare(findChild(grid, "small1").width, (300 - Tokens.spaceS) / 2);
        compare(findChild(grid, "wide").width, 300, "two units wide is the whole row");
    }

    function test_compact_wide_and_big_tiles_span_their_stretched_cells_and_rows_stay_a_tile_unit_high() {
        grid = createTemporaryObject(compactComponent, testCase, {
            width: 600
        });
        const cell = grid.cellWidth;
        const big = findChild(grid, "big");
        compare(findChild(grid, "wide").width, 2 * cell + Tokens.spaceS);
        compare(Qt.rect(big.x, big.y, big.width, big.height), Qt.rect(0, Tokens.tileUnit + Tokens.spaceS, 2 * cell + Tokens.spaceS, 2 * Tokens.tileUnit + Tokens.spaceS));
        const small2 = findChild(grid, "small2");
        compare(Qt.point(small2.x, small2.y), Qt.point(2 * (cell + Tokens.spaceS), Tokens.tileUnit + Tokens.spaceS), "beside the big one");
        compare(grid.implicitHeight, 3 * Tokens.tileUnit + 2 * Tokens.spaceS);
    }

    function test_a_grid_given_an_order_packs_its_tiles_in_it_and_not_in_its_childrens() {
        const small = findChild(grid, "small3");
        const wide = findChild(grid, "wide");
        grid.order = [small, ...grid.children.filter(child => child !== small)];
        compare(Qt.point(small.x, small.y), Qt.point(0, 0));
        compare(wide.x, Tokens.tileUnit + Tokens.spaceS);
    }

    function test_a_tile_removed_while_the_cells_change_width_leaves_the_others_placed_exactly() {
        const compact = createTemporaryObject(compactComponent, testCase, { width: 700 });
        const gone = findChild(compact, "small1");
        compact.order = [...compact.children];
        gone.destroy();
        tryCompare(compact.children, "length", 3);
        compact.width = 680;
        compare(compact.across, 3);
        const kept = compact.placed.filter(cell => cell.tile as Tile);
        compare(kept.length, 3);
        for (const cell of kept) {
            compare(cell.tile.x, cell.column * (compact.cellWidth + Tokens.spaceS), cell.tile.objectName);
            compare(cell.tile.y, cell.row * (Tokens.tileUnit + Tokens.spaceS), cell.tile.objectName);
            compare(cell.tile.width, compact.span(compact.spanOf(cell.tile).columns, compact.cellWidth), cell.tile.objectName);
        }
    }

    function test_compact_a_tile_three_or_four_units_wide_takes_the_whole_row() {
        grid = createTemporaryObject(compactComponent, testCase, {
            width: 600
        });
        const wide = findChild(grid, "wide");
        wide.columns = 4;
        compare(Qt.point(wide.x, wide.y), Qt.point(0, 0));
        compare(wide.width, grid.width, "not past the grid's edge");
        compare(findChild(grid, "small1").y, Tokens.tileUnit + Tokens.spaceS, "the next row takes the rest");
        wide.columns = 3;
        compare(wide.width, grid.width);
    }

    function test_compact_a_grid_that_widens_without_room_for_another_column_stretches_its_cells_along() {
        grid = createTemporaryObject(compactComponent, testCase, {
            width: 600
        });
        grid.width = 650;
        compare(grid.across, 3);
        const small1 = findChild(grid, "small1");
        compare(small1.width, (650 - 2 * Tokens.spaceS) / 3);
        compare(small1.x + small1.width, 650);
    }

    function test_compact_a_wider_grid_takes_another_column_and_the_cells_narrow_again() {
        grid = createTemporaryObject(compactComponent, testCase, {
            width: 600
        });
        grid.width = 4 * Tokens.tileUnit + 3 * Tokens.spaceS;
        compare(grid.across, 4);
        compare(findChild(grid, "small1").width, Tokens.tileUnit);
        compare(Qt.point(findChild(grid, "big").x, findChild(grid, "big").y), Qt.point(0, Tokens.tileUnit + Tokens.spaceS), "the cell left in the first row is too narrow for it");
    }

    function test_a_short_viewport_is_compact_too_and_a_tall_wide_one_gives_the_tiles_their_unit_again() {
        grid = createTemporaryObject(compactComponent, testCase, {
            width: 900,
            placeWidth: 1600,
            viewportHeight: Tokens.bpShortHeight
        });
        verify(grid.stretched, "a viewport 480 px high is compact");
        compare(grid.across, 5);
        verify(findChild(grid, "small1").width > Tokens.tileUnit);
        grid.viewportHeight = 900;
        verify(!grid.stretched);
        compare(grid.across, 4);
        compare(findChild(grid, "small1").width, Tokens.tileUnit);
        compare(findChild(grid, "big").width, 2 * Tokens.tileUnit + Tokens.spaceS);
    }

    function key(code: int, text = ""): var {
        return { key: code, text: text, modifiers: Qt.NoModifier };
    }

    function test_a_grid_that_is_one_tab_stop_is_reached_by_tab_at_the_tile_last_focused_and_left_by_the_next() {
        const column = createTemporaryObject(oneStopComponent, testCase);
        const tile = name => findChild(column, name);
        tile("before").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Tab);
        verify(tile("ton").activeFocus, "the first tile, to begin with");
        keyClick(Qt.Key_Tab);
        verify(tile("after").activeFocus, "the next Tab leaves the grid");
        compare(["ton", "netz", "bluetooth", "anzeige", "sitzung"].filter(name => tile(name).activeFocusOnTab), ["ton"]);
        tile("anzeige").forceActiveFocus();
        tile("after").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(tile("anzeige").activeFocus, "Shift+Tab comes back to the tile last focused");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(tile("before").activeFocus, "and leaves the other way");
        tile("anzeige").visible = false;
        keyClick(Qt.Key_Tab);
        verify(tile("ton").activeFocus, "a tile that went leaves the stop to the first");
    }

    function test_in_a_grid_that_is_one_tab_stop_the_arrows_go_to_the_nearest_tile_that_way_and_stay_at_its_edge() {
        const column = createTemporaryObject(oneStopComponent, testCase);
        const tile = name => findChild(column, name);
        const grid = column.grid;
        tile("ton").forceActiveFocus();
        verify(grid.handleKey(key(Qt.Key_Right)), "→ is the grid's");
        verify(tile("netz").activeFocus);
        verify(grid.handleKey(key(Qt.Key_Right)), "at the edge the grid still takes it");
        verify(tile("netz").activeFocus, "and the focus stays");
        verify(grid.handleKey(key(Qt.Key_Down)));
        verify(tile("bluetooth").activeFocus, "↓ to the wide tile below");
        verify(grid.handleKey(key(Qt.Key_Down)));
        verify(tile("anzeige").activeFocus, "of the two below, the one in line with its start");
        verify(grid.handleKey(key(Qt.Key_Right)));
        verify(tile("sitzung").activeFocus);
        verify(grid.handleKey(key(Qt.Key_Down)));
        verify(tile("sitzung").activeFocus, "the last row's ↓ stays");
        verify(grid.handleKey(key(Qt.Key_Up)));
        verify(tile("bluetooth").activeFocus);
        verify(grid.handleKey(key(Qt.Key_Up)));
        verify(tile("ton").activeFocus);
        verify(grid.handleKey(key(Qt.Key_Left)));
        verify(grid.handleKey(key(Qt.Key_Up)));
        verify(tile("ton").activeFocus, "the first row's ↑ and the first column's ← stay");
        keyClick(Qt.Key_Right);
        verify(tile("netz").activeFocus, "a real key goes the same way");
    }

    function test_in_a_grid_that_is_one_tab_stop_home_and_end_go_to_the_first_and_last_tile_and_a_letter_jumps() {
        const column = createTemporaryObject(oneStopComponent, testCase);
        const tile = name => findChild(column, name);
        const grid = column.grid;
        tile("bluetooth").forceActiveFocus();
        verify(grid.handleKey(key(Qt.Key_End)));
        verify(tile("sitzung").activeFocus, "End: the last");
        verify(grid.handleKey(key(Qt.Key_Home)));
        verify(tile("ton").activeFocus, "Home: the first");
        verify(grid.handleKey(key(Qt.Key_A, "a")));
        verify(tile("anzeige").activeFocus, "a letter: the next tile it starts");
        verify(grid.handleKey(key(Qt.Key_T, "T")));
        verify(tile("ton").activeFocus, "whatever the case, round past the end");
        verify(grid.handleKey(key(Qt.Key_Q, "q")), "a letter no tile starts with is taken too");
        verify(tile("ton").activeFocus, "and the focus stays");
        verify(!grid.handleKey(key(Qt.Key_Escape, "\u001b")), "Escape is left to what holds the grid");
        verify(!grid.handleKey(key(Qt.Key_Tab, "\t")), "and Tab");
        verify(!grid.handleKey(key(Qt.Key_Space, " ")), "and Space");
        verify(!grid.handleKey({ key: Qt.Key_A, text: "a", modifiers: Qt.ControlModifier }), "and Ctrl with a letter");
    }

    function test_a_grid_that_is_no_tab_stop_of_its_own_leaves_the_keys_and_the_tab_stops_to_its_tiles() {
        const column = createTemporaryObject(oneStopComponent, testCase);
        const tile = name => findChild(column, name);
        column.grid.oneTabStop = false;
        tile("ton").forceActiveFocus();
        verify(!column.grid.handleKey(key(Qt.Key_Right)));
        verify(!column.grid.handleKey(key(Qt.Key_End)));
        verify(tile("ton").activeFocus);
    }
}
