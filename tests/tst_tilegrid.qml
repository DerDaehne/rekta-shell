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
}
