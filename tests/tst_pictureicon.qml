pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Qt.labs.sharedimage
import Rekta

// run-qml-tests.sh runs these once more with the display scaled to twice its size: a picture's own size counts in
// logical px there too.
TestCase {
    id: testCase

    name: "PictureIcon"
    visible: true
    when: windowShown
    width: 200
    height: 100

    // Blue squares of 16 and 32px and a blue 40 × 20 picture as PNG; tests/pictures holds more of them as files.
    readonly property string small: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR42mOwKvtAEmIY1TCqYfhqAAByVKAQbSDPuAAAAABJRU5ErkJggg=="
    readonly property string large: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKklEQVR42mOwKvtAU8QwasGoBaMWjFowasGoBaMWjFowasGoBaMWDBULAIMpgFuqhFcIAAAAAElFTkSuQmCC"
    readonly property string wide: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAIAAABwJOjsAAAAJElEQVR42mOwKvswIIhh1OJRi0ctHrV41OJRi0ctHrV45FgMAMClFExPdwFpAAAAAElFTkSuQmCC"

    Component {
        id: iconComponent

        PictureIcon {}
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    // A file through an image provider, the way the shell gets themes' and apps' icons: Qt loads it at the window's
    // pixel ratio.
    function provided(name: string): string {
        return Qt.resolvedUrl(`pictures/${name}`).toString().replace("file://", "image://shared");
    }

    function loaded(source: string): var {
        const icon = createTemporaryObject(iconComponent, testCase, { source });
        tryCompare(icon, "status", Image.Ready);
        compare(icon.width, Geometry.iconSize, "the field keeps its size");
        return findChild(icon, "picture");
    }

    function test_a_picture_smaller_than_its_field_stands_at_its_own_size_in_the_middle_data() {
        return [
            { tag: "data", source: small },
            { tag: "provider", source: provided("blue-16.png") }
        ];
    }

    function test_a_picture_smaller_than_its_field_stands_at_its_own_size_in_the_middle(row) {
        const picture = loaded(row.source);
        compare(picture.width, 16);
        compare(picture.height, 16);
        compare(picture.x, 2);
        compare(picture.y, 2);
    }

    function test_a_larger_picture_comes_down_to_its_field_data() {
        return [
            { tag: "data", source: large },
            { tag: "provider", source: provided("blue-32.png") }
        ];
    }

    function test_a_larger_picture_comes_down_to_its_field(row) {
        const picture = loaded(row.source);
        compare(picture.width, 20);
        compare(picture.height, 20);
        compare(picture.x, 0);
    }

    function test_a_picture_larger_than_its_field_on_one_side_keeps_its_proportions_in_the_middle_of_its_field_data() {
        return [
            { tag: "wide data", source: wide, shown: [0, 5, 20, 10] },
            { tag: "wide provider", source: provided("blue-32x16.png"), shown: [0, 5, 20, 10] },
            { tag: "tall provider", source: provided("blue-16x32.png"), shown: [5, 0, 10, 20] }
        ];
    }

    function test_a_picture_larger_than_its_field_on_one_side_keeps_its_proportions_in_the_middle_of_its_field(row) {
        const picture = loaded(row.source);
        compare([picture.x, picture.y, picture.width, picture.height], row.shown);
    }
}
