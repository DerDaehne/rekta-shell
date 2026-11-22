import QtQuick

// A grid of tiles (layout.md:162–168; rekta.css:87–92, :1513), space-s apart. Each tile takes the first free cells its
// size fits, row by row from the top (grid-auto-flow: dense), so a wide tile never leaves a hole that a narrower one
// after it could fill. Sideways the cells are a tile unit square, `columns` of them across. Compact the grid fills its
// width: as many tile-unit columns as fit, at least two, each stretched to fill the row, rows a tile unit high; a tile
// three or four units wide takes a whole compact row (rekta.css:176).
// ponytail: a compact row stays a tile unit high, where Rekta's grows with content taller than that (minmax(tile-unit,
// auto)); no tile here has such content; add it once a tile's content outgrows a unit. The product keeps one tile-unit
// for every width, ultrawide included.
Item {
    id: grid

    // The columns sideways. The tiles take at least one: in none a tile would look for a place forever.
    property int columns: 4
    // The tiles in the order they take their cells; null for the order of its children. A Repeater whose model moves
    // its items keeps them in the model's order, not its parent's children, so its host gives that order here.
    property var order: null
    property real placeWidth: Window.width
    property real viewportHeight: Window.height
    readonly property bool stretched: Prefs.sizeClass(placeWidth, viewportHeight) === "compact"
    // repeat(auto-fill, minmax(min(tile-unit, (100% - gap) / 2), 1fr)) (rekta.css:90)
    readonly property int across: stretched ? Math.max(2, Math.floor((width + Tokens.spaceS) / (Tokens.tileUnit + Tokens.spaceS))) : Math.max(1, columns)
    readonly property real cellWidth: stretched ? Math.max(0, (width - (across - 1) * Tokens.spaceS) / across) : Tokens.tileUnit
    // Where each visible tile sits, in cells: [{tile, column, row}], in the order of the children.
    readonly property var placed: pack()
    readonly property int rows: placed.reduce((most, cell) => Math.max(most, cell.row + cell.tile.rows), 0)
    // A grid of tiles that open is one tab stop where its host says so (navigation.md:546–559): Tab reaches the tile last
    // focused, the first to begin with, and the next Tab leaves the grid. The Start leads the keys across its sections
    // itself.
    property bool oneTabStop: false
    // The tile Tab reaches.
    readonly property Tile tabStop: oneTabStop ? (shownTiles().includes(lastFocused) ? lastFocused : shownTiles()[0] ?? null) : null
    property Tile lastFocused: null

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
        const tiles = [...(order ?? children)].filter(child => (child as Tile)?.visible);
        return packed(tiles.map(spanOf), across).map((cell, k) => ({ tile: tiles[k], column: cell.column, row: cell.row }));
    }

    // A tile spanning cells spans the gaps between them too.
    function span(count: int, cell: real): real {
        return count * cell + (count - 1) * Tokens.spaceS;
    }

    function shownTiles(): list<Tile> {
        return placed.map(cell => cell.tile).filter(tile => tile as Tile);
    }

    // In a grid that is one tab stop: the arrows go to the nearest tile that way, and at the edge the focus stays; Home
    // and End go to the first and last tile; a letter to the next one whose name starts with it. True when it took the
    // key.
    function handleKey(event: var): bool {
        const tiles = shownTiles();
        const from = tiles.find(tile => tile.activeFocus);
        if (!oneTabStop || !from)
            return false;
        const directions = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down" };
        let to = -1;
        if (event.key in directions)
            to = TileFocus.neighbour(from, tiles, directions[event.key]);
        else if (event.key === Qt.Key_Home || event.key === Qt.Key_End)
            to = event.key === Qt.Key_Home ? 0 : tiles.length - 1;
        else if (isLetterOrDigit(event.text ?? "") && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            to = TileFocus.jumpTarget(tiles.map(tile => tile.Accessible.name), tiles.indexOf(from), event.text);
        else
            return false;
        tiles[to]?.forceActiveFocus(Qt.TabFocusReason);
        return true;
    }

    // A letter has a case (QML's regular expressions know no \p{L}).
    function isLetterOrDigit(text: string): bool {
        return text.length === 1 && (text.toLowerCase() !== text.toUpperCase() || (text >= "0" && text <= "9"));
    }

    function markTabStop() {
        if (!oneTabStop)
            return;
        for (const child of children) {
            if (child as Tile)
                child.activeFocusOnTab = child === tabStop;
        }
    }

    // A tile destroyed since `placed` was last computed reads as null here; the next `placed` leaves it out.
    function apply() {
        for (const cell of placed) {
            if (!(cell.tile as Tile))
                continue;
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
    onTabStopChanged: markTabStop()
    Component.onCompleted: markTabStop()
    Keys.onPressed: event => event.accepted = handleKey(event)

    Connections {
        target: grid.oneTabStop ? grid.Window.window : null

        function onActiveFocusItemChanged() {
            const focused = grid.Window.activeFocusItem as Tile;
            if (focused?.parent === grid)
                grid.lastFocused = focused;
        }
    }
}
