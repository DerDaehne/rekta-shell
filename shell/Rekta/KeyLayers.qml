pragma Singleton
import QtQuick

// One key dispatcher for the whole app (navigation.md, "Who gets a key"; behaviour.md, `keys.on`): the innermost thing
// that is open gets a key first, and once a layer uses it nothing below sees it. Priorities, highest first: a tip 45,
// floating surfaces 40, a focused toast 30, its undo 25, a selection 20, the place 10, the palette 5, undo 4.
// Components take their keys on their own item before any layer: a host routes only what nobody took, from its root
// item: `Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)`.
QtObject {
    id: keyLayers

    // { priority, handler }, highest first.
    property var layers: []
    // The floating surfaces and modals open now; while there is one, Escape belongs to it.
    property var surfaces: []

    // handler(event, focusItem) returns true when it used the key. Returns a function that removes the layer.
    function on(priority: real, handler: var): var {
        const layer = { priority: priority, handler: handler };
        layers = [...layers, layer].sort((a, b) => b.priority - a.priority);
        return () => {
            layers = layers.filter(l => l !== layer);
        };
    }

    function dispatch(event: KeyEvent, focusItem: Item): bool {
        for (const layer of layers) {
            if (layer.handler(event, focusItem)) {
                event.accepted = true;
                return true;
            }
        }
        return false;
    }

    function opened(surface: Item) {
        if (!surfaces.includes(surface))
            surfaces = [...surfaces, surface];
    }

    function closed(surface: Item) {
        surfaces = surfaces.filter(s => s !== surface);
    }

    // Escape may go back only when nothing nearer wants it: not from a text field, not while a menu or modal is open.
    function escapeIsFree(focusItem: Item): bool {
        if (surfaces.length > 0)
            return false;
        return !(focusItem instanceof TextInput || focusItem instanceof TextEdit);
    }
}
