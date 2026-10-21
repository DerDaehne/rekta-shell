pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "TextRoles"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1200
    height: 900

    readonly property string longTitle: "Nightly build of release-2026-10 failed on runner three because the cache volume was full and the retry hit the same runner again"

    Component {
        id: roles

        Item {
            property alias kicker: kicker
            property alias facts: facts
            property alias body: body
            property alias meta: meta
            property alias title: title
            property alias group: group
            property alias nav: nav
            property alias pivot: pivot
            property alias hint: hint
            property alias tag: tag
            property alias stat: stat
            property alias message: message

            width: 400

            Kicker { id: kicker }
            Facts { id: facts }
            Body { id: body }
            Meta { id: meta }
            Title { id: title; placeWidth: 1000 }
            GroupHeading { id: group; placeWidth: 1000 }
            NavTitle { id: nav; placeWidth: 1000 }
            PivotTitle { id: pivot; placeWidth: 1000 }
            Hint { id: hint }
            StatusTag { id: tag }
            Stat { id: stat; placeWidth: 1000 }
            TileMessage { id: message }
        }
    }

    Component {
        id: metricsComponent

        FontMetrics {}
    }

    Component {
        id: sheetComponent

        // Every text role on both themes' ground: kicker, title, facts, body, group, nav and pivot titles, meta.
        Row {
            Repeater {
                model: ["light", "dark"]

                delegate: Rectangle {
                    id: themeBox

                    required property string modelData

                    width: 560
                    height: column.height + 2 * Tokens.spaceL
                    color: Tokens[modelData].bg

                    Column {
                        id: column

                        x: Tokens.spaceL
                        y: Tokens.spaceL
                        width: parent.width - 2 * Tokens.spaceL
                        spacing: Tokens.spaceS

                        Kicker { text: "nightly import · 12 min ago"; color: Tokens[themeBox.modelData].textContrastHigh }
                        Title { width: parent.width; placeWidth: 560; text: testCase.longTitle; color: Tokens[themeBox.modelData].textPrimary }
                        Facts { width: parent.width; text: "30 of 30 runs · median 4 min 12 s"; color: Tokens[themeBox.modelData].textContrastHigh }
                        Hairline { width: parent.width; color: Tokens[themeBox.modelData].textContrastLow }
                        Body { width: parent.width; text: "It has run every night this month without a retry, and the cache stays below its limit."; color: Tokens[themeBox.modelData].textPrimary }
                        GroupHeading { placeWidth: 560; text: "recent runs"; color: Tokens[themeBox.modelData].textPrimary }
                        NavTitle { placeWidth: 560; text: "builds"; color: Tokens[themeBox.modelData].textPrimary }
                        NavTitle { placeWidth: 560; active: false; text: "runners"; color: Tokens[themeBox.modelData].textContrastMedium }
                        PivotTitle { placeWidth: 560; text: "today"; color: Tokens[themeBox.modelData].textPrimary }
                        PivotTitle { placeWidth: 560; active: false; text: "this week"; color: Tokens[themeBox.modelData].textContrastMedium }
                        Meta { text: "12:04 · 1,234 · 1,111 · 9,876"; color: Tokens[themeBox.modelData].textContrastHigh }
                    }
                }
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    function test_every_role_takes_its_values_from_the_tokens() {
        const r = createTemporaryObject(roles, testCase);
        const expected = [
            [r.kicker, Tokens.fontSizeXs, Tokens.fontWeightSemibold, Tokens.color.textContrastHigh],
            [r.facts, Tokens.fontSizeXs, Tokens.fontWeightRegular, Tokens.color.textContrastHigh],
            [r.body, Tokens.fontSizeS, Tokens.fontWeightRegular, Tokens.color.textPrimary],
            [r.meta, Tokens.fontSizeXxs, Tokens.fontWeightRegular, Tokens.color.textContrastHigh],
            [r.title, Tokens.fluid(Tokens.fontSizeTitle, 1000), Tokens.fontWeightSemibold, Tokens.color.textPrimary],
            [r.group, Tokens.fluid(Tokens.fontSizeGroup, 1000), Tokens.fontWeightRegular, Tokens.color.textPrimary],
            [r.nav, Tokens.fluid(Tokens.fontSizeNavActive, 1000), Tokens.fontWeightLight, Tokens.color.textPrimary],
            [r.pivot, Tokens.fluid(Tokens.fontSizePivotActive, 1000), Tokens.fontWeightLight, Tokens.color.textPrimary]
        ];
        for (const [text, size, weight, colour] of expected) {
            compare(text.font.family, Tokens.fontSans);
            compare(text.font.pixelSize, Math.round(size));
            compare(text.font.weight, weight);
            compare(text.color, colour);
        }
    }

    function test_the_kicker_is_tracked_and_meta_figures_are_tabular() {
        const r = createTemporaryObject(roles, testCase);
        // Qt keeps letter spacing in 1/64 px steps.
        fuzzyCompare(r.kicker.font.letterSpacing, Geometry.kickerLetterSpacing * Tokens.fontSizeXs, 1 / 64);
        compare(r.meta.font.features["tnum"], 1);
    }

    // Every text role with the line-height token rekta.css gives it (:35, :51, :53, :86, :95, :105, :159, :609).
    function linesOf(r) {
        return [
            ["kicker", r.kicker, Tokens.lineHeightBody],
            ["facts", r.facts, Tokens.lineHeightBody],
            ["body", r.body, Tokens.lineHeightBody],
            ["meta", r.meta, Tokens.lineHeightBody],
            ["title", r.title, Tokens.lineHeightTitle],
            ["group heading", r.group, Tokens.lineHeightTight],
            ["navigation title", r.nav, Tokens.lineHeightNav],
            ["pivot title", r.pivot, Tokens.lineHeightNav],
            ["hint", r.hint, Tokens.lineHeightBody],
            ["status tag", findChild(r.tag, "word"), Tokens.lineHeightCompact],
            ["stat number", findChild(r.stat, "number"), Geometry.statLineHeight],
            ["stat words", findChild(r.stat, "words"), Tokens.lineHeightCompact],
            ["message", findChild(r.message, "sentence"), Tokens.lineHeightCompact],
            ["message kicker", findChild(r.message, "kicker"), Tokens.lineHeightCompact],
            ["message facts", findChild(r.message, "facts"), Tokens.lineHeightCompact]
        ];
    }

    function test_every_role_draws_lines_as_tall_as_its_size_times_its_line_height_token() {
        const r = createTemporaryObject(roles, testCase);
        for (const [role, text, lineHeight] of linesOf(r)) {
            text.text = "one\ntwo\nthree";
            compare(text.lineCount, 3, role);
            fuzzyCompare(text.height, 3 * text.font.pixelSize * lineHeight, 1e-9, role);
        }
    }

    function test_the_first_baseline_sits_half_the_leading_below_the_top_as_in_css() {
        const r = createTemporaryObject(roles, testCase);
        for (const [role, text, lineHeight] of linesOf(r)) {
            text.text = "one\ntwo";
            const font = createTemporaryObject(metricsComponent, testCase, { font: text.font });
            const halfLeading = (text.font.pixelSize * lineHeight - font.ascent - font.descent) / 2;
            fuzzyCompare(text.baselineOffset, halfLeading + font.ascent, 1e-9, role);
        }
    }

    function test_navigation_titles_shrink_and_recede_when_inactive() {
        const r = createTemporaryObject(roles, testCase);
        r.nav.active = false;
        compare(r.nav.font.pixelSize, Math.round(Tokens.fluid(Tokens.fontSizeNavInactive, 1000)));
        compare(r.nav.color, Tokens.color.textContrastMedium);
        r.pivot.active = false;
        compare(r.pivot.font.pixelSize, Math.round(Tokens.fluid(Tokens.fontSizePivotInactive, 1000)));
        compare(r.pivot.color, Tokens.color.textContrastMedium);
    }

    function test_a_long_title_wraps_to_three_lines_then_ends_in_an_ellipsis() {
        const r = createTemporaryObject(roles, testCase);
        r.title.width = 400;
        r.title.text = testCase.longTitle;
        waitForRendering(r.title);
        compare(r.title.lineCount, Geometry.titleMaxLines);
        verify(r.title.truncated);
        compare(r.title.elide, Text.ElideRight);
    }

    function test_a_title_breaks_a_word_too_long_for_its_line() {
        const r = createTemporaryObject(roles, testCase);
        r.title.width = 200;
        r.title.text = "https://example.invalid/an/address/without/any/spaces/in/it";
        waitForRendering(r.title);
        verify(r.title.lineCount > 1);
        verify(r.title.contentWidth <= 200);
    }

    function test_fluid_titles_follow_the_place_width() {
        const r = createTemporaryObject(roles, testCase);
        r.title.placeWidth = 400;
        compare(r.title.font.pixelSize, Math.round(Tokens.fluid(Tokens.fontSizeTitle, 400)));
        r.title.placeWidth = 4000;
        compare(r.title.font.pixelSize, Math.round(Tokens.fontSizeTitle.max));
        r.title.text = "one\ntwo";
        fuzzyCompare(r.title.height, 2 * Tokens.fontSizeTitle.max * Tokens.lineHeightTitle, 1e-9, "the line box grows with the size");
    }

    function test_contact_sheet_of_all_roles_in_both_themes() {
        const sheet = createTemporaryObject(sheetComponent, testCase);
        waitForRendering(sheet);
        grabImage(sheet).save("text-sheet.png");
        verify(sheet.width > 0 && sheet.height > 0);
    }
}
