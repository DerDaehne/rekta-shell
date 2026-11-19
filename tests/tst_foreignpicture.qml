import QtQuick
import QtTest
import Rekta

TestCase {
    name: "ForeignPicture"

    function themed(name: string): string {
        return `theme:${name}`;
    }

    function test_a_plain_icon_name_is_the_themes_to_resolve() {
        compare(ForeignPicture.source("konsole", themed), "theme:konsole");
        compare(ForeignPicture.source("konsole"), "", "without a theme there is no picture");
    }

    function test_a_file_uri_stands_as_it_is() {
        compare(ForeignPicture.source("file:///usr/share/icons/a.png", themed), "file:///usr/share/icons/a.png");
    }

    function test_an_absolute_path_becomes_a_file_uri_with_its_odd_characters_escaped() {
        compare(ForeignPicture.source("/usr/share/a b#c.png", themed), "file:///usr/share/a%20b%23c.png");
    }

    function test_the_shells_own_image_providers_stand_as_they_are() {
        compare(ForeignPicture.source("image://icon/mail-client", themed), "image://icon/mail-client");
        compare(ForeignPicture.source("image://qsimage/3", themed), "image://qsimage/3");
    }

    function test_no_other_scheme_gives_a_picture_so_nothing_is_fetched() {
        for (const url of ["http://127.0.0.1:1/a.png", "https://example.org/a.png", "HTTP://example.org/a.png", "ftp://example.org/a.png",
                "data:image/png;base64,AAAA", "image://icon/http://example.org/a.png", "qrc:/a.png", "file://host/share/a.png", "//example.org/a.png", "relative/a.png", "../a.png"])
            compare(ForeignPicture.source(url, themed), "", url);
    }

    function test_what_is_no_string_or_is_empty_gives_none() {
        for (const value of ["", undefined, null, 3, {}])
            compare(ForeignPicture.source(value, themed), "");
    }
}
