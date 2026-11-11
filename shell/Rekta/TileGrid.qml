import QtQuick

// A grid of tiles (layout.md:110–116; rekta.css:83–88, :1481), space-s apart. Each tile takes the first free cells its
// size fits, row by row from the top (grid-auto-flow: dense), so a wide tile never leaves a hole that a narrower one
// after it could fill. Sideways the cells are a tile unit square, `columns` of them across. Compact the grid fills its
// width: as many tile-unit columns as fit, at least two, each stretched to fill the row, rows a tile unit high; a tile
// three or four units wide takes a whole compact row (rekta.css:172).
// ponytail: a compact row stays a tile unit high, where Rekta's grows with content taller than that (minmax(tile-unit,
// auto)); no tile here has such content; add it once a tile's content outgrows a unit. The product keeps one tile-unit
// for every width, ultrawide included.
Item {
    id: grid

    // The columns sideways. The tiles take at least one: in none a tile would look for a place forever.
    property int columns: 4
    property real placeWidth: Window.width
    property real viewportHeight: Window.height
    readonly property bool stretched: Prefs.sizeClass(placeWidth, viewportHeight) === "compact"
    // repeat(auto-fill, minmax(min(tile-unit, (100% - gap) / 2), 1fr)) (rekta.css:86)
    readonly property int across: stretched ? Math.max(2, Math.floor((width + Tokens.spaceS) / (Tokens.tileUnit + Tokens.spaceS))) : Math.max(1, columns)
    readonly property real cellWidth: stretched ? Math.max(0, (width - (across - 1) * Tokens.spaceS) / across) : Tokens.tileUnit
    // Where each visible tile sits, in cells: [{tile, column, row}], in the order of the children.
    readonly property var placed: pack()
    readonly property int rows: placed.reduce((most, cell) => Math.max(most, cell.row + cell.tile.rows), 0)

    // The cells a tile or a span ({columns, rows}) covers from `column`, `row`, as "row,column" keys.
    function cellsOf(column: int, row: int, tile: var): var {
        const keys = [];
        for (let r = row; r < row + tile.rows; r++) {
            for (let c = column; c < column + tile.columns; c++)
                keys.push(`${r},${c}`);
        }
        return keys;
    }

    // A tile wider than the grid still takes the first column, as an implicit grid column would.
    function fits(taken: var, column: int, row: int, tile: var, wide: int): bool {
        if (column > 0 && column + tile.columns > wide)
            return false;
        return cellsOf(column, row, tile).every(key => !taken.has(key));
    }

    // Dense packing into `wide` columns: every span ({columns, rows}) scans from the first cell for the first place it
    // fits. [{column, row}] in the order of the spans. It reads nothing of the grid, so a host may ask about any width.
    function packed(spans: var, wide: int): var {
        const taken = new Set();
        return spans.map(size => {
            let at = 0;
            while (!fits(taken, at % wide, Math.floor(at / wide), size, wide))
                at++;
            const cell = { column: at % wide, row: Math.floor(at / wide) };
            cellsOf(cell.column, cell.row, size).forEach(key => taken.add(key));
            return cell;
        });
    }

    // The rows the spans take, packed into `wide` columns.
    function rowsOf(spans: var, wide: int): int {
        return packed(spans, wide).reduce((most, cell, k) => Math.max(most, cell.row + spans[k].rows), 0);
    }

    // The cells a tile spans here: compact, one three or four units wide spans the row.
    function spanOf(tile: Tile): var {
        return stretched && tile.columns > 2 ? { columns: across, rows: tile.rows } : { columns: tile.columns, rows: tile.rows };
    }

    function pack(): var {
        const tiles = [...children].filter(child => (child as Tile)?.visible);
        return packed(tiles.map(spanOf), across).map((cell, k) => ({ tile: tiles[k], column: cell.column, row: cell.row }));
    }

    // A tile spanning cells spans the gaps between them too.
    function span(count: int, cell: real): real {
        return count * cell + (count - 1) * Tokens.spaceS;
    }

    function apply() {
        for (const cell of placed) {
            cell.tile.x = cell.column * (cellWidth + Tokens.spaceS);
            cell.tile.y = cell.row * (Tokens.tileUnit + Tokens.spaceS);
            cell.tile.width = span(spanOf(cell.tile).columns, cellWidth);
            cell.tile.height = span(cell.tile.rows, Tokens.tileUnit);
        }
    }

    implicitWidth: span(columns, Tokens.tileUnit)
    implicitHeight: rows > 0 ? span(rows, Tokens.tileUnit) : 0

    onPlacedChanged: apply()
    onCellWidthChanged: apply()
}
