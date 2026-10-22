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
}
