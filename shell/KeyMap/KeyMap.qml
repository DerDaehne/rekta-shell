pragma ComponentBehavior: Bound

import QtQuick
import Rekta
import Start

// The shell's keyboard shortcuts, listed in the shell itself as Rekta lists an app's (navigation.md:478–479): a sheet
// with a row per shortcut, its words and its key, and "schließen" (Rekta's showcase, site/index.html:918–941). The
// keys of the session's shortcuts are read from kglobalaccel as it opens, so what the user bound shows; a shortcut with
// no key bound has no row. `?` outside a text field asks for it (navigation.md:473).
Sheet {
    id: keyMap

    required property var launcher
    // The shortcuts in their order: {text, component, action} for one kglobalaccel holds, {text, key} for Rekta's own.
    property var shortcuts: [
        {
            text: "den start öffnen oder schließen",
            component: "rekta-shell",
            action: "start"
        },
        {
            text: "die steuerung öffnen",
            component: "rekta-shell",
            action: "controls"
        },
        {
            text: "die meldungen öffnen",
            component: "rekta-shell",
            action: "notifications"
        },
        {
            text: "sperren",
            component: "ksmserver",
            action: "Lock Session"
        },
        {
            text: "abmelden, neu starten oder ausschalten",
            component: "ksmserver",
            action: "Log Out"
        },
        {
            text: "diese liste",
            key: "?"
        },
        {
            text: "zurück oder schließen, was offen ist",
            key: "Esc"
        },
        {
            text: "rückgängig machen",
            key: "Ctrl+Z"
        }
    ]
    // The keys kglobalaccel replied, by "component/action".
    property var bound: ({})
    readonly property var rows: shortcuts.map(shortcut => ({
                text: shortcut.text,
                key: shortcut.key ?? bound[`${shortcut.component}/${shortcut.action}`] ?? ""
            })).filter(row => row.key !== "")

    // `?` asked for the list.
    signal asked

    function readKeys() {
        for (const shortcut of shortcuts.filter(shortcut => shortcut.action !== undefined)) {
            launcher.ask("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "shortcutKeys", [[shortcut.component, shortcut.action, "", ""]], "as", values => {
                bound = Object.assign({}, bound, {
                    [`${shortcut.component}/${shortcut.action}`]: Rules.keyText(values)
                });
            });
        }
    }

    // Outside a text field only, as there: a field takes the `?` it types before any layer sees it.
    function asksForList(event: KeyEvent): bool {
        const chord = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0;
        if (event.text !== "?" || chord || KeyLayers.surfaces.length > 0)
            return false;
        asked();
        return true;
    }

    kicker: "hilfe"
    title: "tastenkürzel"
    closeButton: false

    // Below the open toast's undo, as Rekta's showcase puts it (site.js:413–416).
    property var removeLayer

    Component.onCompleted: removeLayer = KeyLayers.on(5, event => keyMap.asksForList(event))

    Component.onDestruction: removeLayer()

    // `.rk-rows`: each row a hairline above, the last one below too (rekta.css:73–75).
    Column {
        objectName: "rows"
        width: parent.width

        Repeater {
            model: keyMap.rows

            ShortcutRow {}
        }

        Hairline {
            width: parent.width
        }
    }

    Actions {
        width: parent.width

        Button {
            objectName: "schliessen"
            variant: "primary"
            text: "schließen"
            onClicked: keyMap.request("cancel")
        }
    }

    // `.rk-rows > li { justify-content: space-between; padding: space-s 0 }` (rekta.css:74), the key centred beside
    // the words (site.css:61).
    component ShortcutRow: Item {
        id: row

        required property var modelData

        width: parent.width
        implicitHeight: Math.max(words.implicitHeight, key.implicitHeight) + 2 * Tokens.spaceS
        Accessible.role: Accessible.StaticText
        Accessible.name: `${modelData.text}: ${modelData.key}`

        Hairline {
            width: parent.width
        }

        Body {
            id: words

            anchors.left: parent.left
            anchors.right: key.left
            anchors.rightMargin: Tokens.spaceM
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.text
        }

        KeyHint {
            id: key

            objectName: "key"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.key
        }
    }
}
