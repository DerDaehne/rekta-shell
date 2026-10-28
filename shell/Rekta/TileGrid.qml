import QtQuick

// A grid of tiles (layout.md, "Tile grids"; rekta.css:76–80, :1166): fixed tile-unit cells space-s apart, sideways. Each
// tile takes the first free cells its size fits, row by row from the top (grid-auto-flow: dense), so a wide tile never
// leaves a hole that a narrower one after it could fill.
// ponytail: sideways cells of tile-unit only. Compact stretches them to fill the row, at least two across; add that
// with the first compact grid. The product keeps one tile-unit for every width, ultrawide included.
Item {
    id: grid

    property int columns: 4
    // Where each visible tile sits, in cells: [{tile, column, row}], in the order of the children.
    readonly property var placed: pack()
    readonly property int rows: placed.reduce((most, cell) => Math.max(most, cell.row + cell.tile.rows), 0)

    // The cells a tile covers from `column`, `row`, as "row,column" keys.
    function cellsOf(column: int, row: int, tile: Tile): var {
        const keys = [];
        for (let r = row; r < row + tile.rows; r++) {
            for (let c = column; c < column + tile.columns; c++)
                keys.push(`${r},${c}`);
        }
        return keys;
    }

    // A tile wider than the grid still takes the first column, as an implicit grid column would.
    function fits(taken: var, column: int, row: int, tile: Tile): bool {
        if (column > 0 && column + tile.columns > columns)
            return false;
        return cellsOf(column, row, tile).every(key => !taken.has(key));
    }

    // Dense packing: every tile scans from the first cell for the first place it fits.
    function pack(): var {
        const taken = new Set();
        const cells = [];
        for (const child of children) {
            const tile = child as Tile;
            if (!tile?.visible)
                continue;
            let at = 0;
            while (!fits(taken, at % columns, Math.floor(at / columns), tile))
                at++;
            const cell = { tile: tile, column: at % columns, row: Math.floor(at / columns) };
            cellsOf(cell.column, cell.row, tile).forEach(key => taken.add(key));
            cells.push(cell);
        }
        return cells;
    }

    function apply() {
        const step = Tokens.tileUnit + Tokens.spaceS;
        for (const cell of placed) {
            cell.tile.x = cell.column * step;
            cell.tile.y = cell.row * step;
        }
    }

    implicitWidth: columns * Tokens.tileUnit + (columns - 1) * Tokens.spaceS
    implicitHeight: rows > 0 ? rows * Tokens.tileUnit + (rows - 1) * Tokens.spaceS : 0

    onPlacedChanged: apply()
}
