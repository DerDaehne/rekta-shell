pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Icon"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1600
    height: 400

    Component {
        id: iconComponent

        Icon {}
    }

    Component {
        id: sheetComponent

        // Every icon at the small and the grid size, on both themes' ground, in their text colour.
        Row {
            Repeater {
                model: ["light", "dark"]

                delegate: Rectangle {
                    id: themeBox

                    required property string modelData
                    readonly property var colours: Tokens[modelData]

                    width: sizes.width + 2 * Tokens.spaceM
                    height: sizes.height + 2 * Tokens.spaceM
                    color: colours.bg

                    Column {
                        id: sizes

                        x: Tokens.spaceM
                        y: Tokens.spaceM
                        spacing: Tokens.spaceM

                        Repeater {
                            model: [16, IconData.grid]

                            delegate: Flow {
                                id: row

                                required property int modelData

                                width: 25 * (IconData.grid + Tokens.spaceS)
                                spacing: Tokens.spaceS

                                Repeater {
                                    model: Object.keys(IconData.icons)

                                    delegate: Icon {
                                        required property string modelData

                                        name: modelData
                                        size: row.modelData
                                        color: themeBox.colours.textPrimary
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function test_strokes_are_flat_mitred_and_unfilled() {
        const icon = createTemporaryObject(iconComponent, testCase, { name: "check" });
        const stroke = findChild(icon, "stroke");
        compare(stroke.strokeWidth, IconData.strokeWidth);
        compare(stroke.capStyle, ShapePath.FlatCap);
        compare(stroke.joinStyle, ShapePath.MiterJoin);
        compare(stroke.fillColor.a, 0);
        compare(stroke.strokeColor, Tokens.color.textPrimary);
    }

    function test_solid_shapes_fill_in_the_icon_colour() {
        for (const name of ["more", "grip", "theme"]) {
            const icon = createTemporaryObject(iconComponent, testCase, { name: name, color: Tokens.color.statusInfoFull });
            const fill = findChild(icon, "fill");
            verify(IconData.icons[name].fill.length > 0, name);
            compare(fill.fillColor, Tokens.color.statusInfoFull, name);
            compare(fill.strokeColor.a, 0, name);
        }
    }

    function test_an_unknown_name_warns_once_and_draws_nothing() {
        ignoreWarning(/Icon: no icon named "nope"/);
        const icon = createTemporaryObject(iconComponent, testCase, { name: "nope" });
        failOnWarning(/no icon named/);
        icon.size = 32;
        waitForRendering(icon);
        compare(icon.paths, null);
        compare(icon.children[0].visible, false);
    }

    function test_every_icon_draws_at_both_sizes_in_both_themes() {
        const sheet = createTemporaryObject(sheetComponent, testCase);
        waitForRendering(sheet);
        const image = grabImage(sheet);
        image.save("icon-sheet.png");
        const icons = iconsBelow(sheet);
        compare(icons.length, Object.keys(IconData.icons).length * 4);
        for (const icon of icons) {
            const ground = Qt.colorEqual(icon.color, Tokens.light.textPrimary) ? Tokens.light.bg : Tokens.dark.bg;
            verify(hasInk(image, sheet, icon, ground), `${icon.name} at ${icon.size} on ${ground}`);
        }
    }

    function iconsBelow(item: Item): list<Item> {
        const own = item instanceof Icon ? [item] : [];
        return own.concat(...Array.from(item.children).map(child => iconsBelow(child)));
    }

    // Antialiased thin diagonals cover no pixel completely, so a pixel counts once it is closer to the ink than to the ground.
    function hasInk(image, sheet, icon, ground): bool {
        const origin = icon.mapToItem(sheet, 0, 0);
        const distance = (a, b) => Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b);
        const full = distance(icon.color, ground);
        for (let y = 0; y < icon.size; y++) {
            for (let x = 0; x < icon.size; x++) {
                if (distance(image.pixel(Math.round(origin.x) + x, Math.round(origin.y) + y), icon.color) < full / 2)
                    return true;
            }
        }
        return false;
    }
}
