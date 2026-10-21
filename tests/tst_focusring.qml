pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "FocusRing"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 400

    Component {
        id: focusable

        Rectangle {
            property alias ring: ring

            width: 120
            height: 80
            activeFocusOnTab: true
            color: Tokens.color.statusErrorTile

            FocusRing {
                id: ring

                onFill: true
            }
        }
    }

    Component {
        id: sheetComponent

        // A ring on every status tile and on both neutral grounds, in both themes.
        Column {
            Repeater {
                model: ["light", "dark"]

                delegate: Rectangle {
                    id: themeBox

                    required property string modelData
                    readonly property var colours: Tokens[modelData]

                    width: row.width + 2 * Tokens.spaceL
                    height: row.height + 2 * Tokens.spaceL
                    color: colours.bg

                    Row {
                        id: row

                        x: Tokens.spaceL
                        y: Tokens.spaceL
                        spacing: Tokens.spaceL

                        Repeater {
                            model: ["Info", "Success", "Warning", "Error", "", "surface"]

                            delegate: Rectangle {
                                id: sample

                                required property string modelData
                                readonly property bool isTile: modelData !== "" && modelData !== "surface"

                                width: 120
                                height: 80
                                radius: Tokens.radiusTile
                                color: isTile ? themeBox.colours[`status${modelData}Tile`] : modelData === "surface" ? themeBox.colours.surface : themeBox.colours.bg

                                Body {
                                    anchors.centerIn: parent
                                    text: sample.isTile ? sample.modelData.toLowerCase() : sample.modelData || "bg"
                                    color: themeBox.colours.textPrimary
                                }

                                FocusRing {
                                    onFill: sample.isTile
                                    ink: themeBox.colours.textPrimary
                                    shown: true
                                    border.color: onFill ? ink : themeBox.colours.focus
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function test_on_a_fill_the_ring_sits_inside_in_the_text_colour() {
        const item = createTemporaryObject(focusable, testCase);
        const ring = item.ring;
        const inset = Geometry.focusRingInsetOnFill - Geometry.focusRingWidth;
        compare(ring.x, inset);
        compare(ring.width, item.width - 2 * inset);
        compare(ring.border.width, Geometry.focusRingWidth);
        compare(ring.border.color, Tokens.color.textPrimary);
    }

    function test_on_a_neutral_ground_the_ring_sits_outside_in_focus() {
        const item = createTemporaryObject(focusable, testCase, { color: Tokens.color.bg });
        item.ring.onFill = false;
        const outset = Geometry.focusRingOffset + Geometry.focusRingWidth;
        compare(item.ring.x, -outset);
        compare(item.ring.width, item.width + 2 * outset);
        compare(item.ring.border.color, Tokens.color.focus);
    }

    function test_the_ring_shows_while_its_target_has_focus() {
        const item = createTemporaryObject(focusable, testCase);
        verify(!item.ring.visible);
        item.forceActiveFocus();
        verify(item.ring.visible);
        item.focus = false;
        verify(!item.ring.visible);
    }

    function test_contact_sheet_of_rings_on_every_status_fill_and_neutral_ground() {
        const sheet = createTemporaryObject(sheetComponent, testCase);
        waitForRendering(sheet);
        grabImage(sheet).save("focus-ring-sheet.png");
        verify(sheet.width > 0 && sheet.height > 0);
    }
}
