pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "TileContentPatterns"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 1200

    readonly property string longSentence: "The import has run every night this month, and every run finished well inside its window without a single retry, so nothing waits for anyone and the next run starts tonight at two."

    Component {
        id: statTile

        Tile {
            Stat {
                objectName: "stat"
                value: "412"
                label: "tests run"
            }
        }
    }

    Component {
        id: progressTile

        Tile {
            Stat {
                value: "60%"
                label: "imported"
            }
            Progress {
                objectName: "progress"
                width: parent.width
                value: 0.6
            }
        }
    }

    Component {
        id: messageTile

        Tile {
            TileMessage {
                objectName: "message"
                kicker: "nightly import"
                facts: "30 of 30 runs"
            }
        }
    }

    Component {
        id: crowdedTile

        Tile {
            id: crowded

            property bool overfull: false

            Stat {
                objectName: "stat"
                value: "412"
                label: "tests run"
            }
            Progress {
                width: parent.width
                value: 0.6
            }
            TileMessage {
                text: "Three failed."
            }
            Stat {
                visible: crowded.overfull
                value: "3"
                label: "failed"
            }
        }
    }

    Component {
        id: statComponent

        Stat {
            value: "412"
            label: "tests run"
        }
    }

    Component {
        id: buttonComponent

        Button {
            text: "archive"
            disabledReason: "Archive needs at least one done job."
        }
    }

    Component {
        id: figuresComponent

        Figures {
            Stat {
                objectName: "first"
                value: "412"
                label: "tests run"
            }
            Stat {
                objectName: "second"
                value: "3"
                label: "failed"
            }
            Stat {
                objectName: "third"
                value: "6 min"
                label: "left"
            }
        }
    }

    Component {
        id: regionComponent

        Rectangle {
            width: 600
            height: region.height
            color: Tokens.color.bg

            // Whatever lies beneath the region gets the presses the region does not take.
            MouseArea {
                property int presses: 0

                objectName: "beneath"
                anchors.fill: parent
                onPressed: presses++
            }

            StatusRegion {
                id: region

                objectName: "region"
                width: parent.width
                kicker: "nightly build"
                status: "info"
                word: "running"
                figures: [
                    Stat {
                        value: "412"
                        label: "tests run"
                    },
                    Stat {
                        value: "3"
                        label: "failed"
                    }
                ]

                Button {
                    objectName: "pause"
                    text: "pause"
                }
                Button {
                    objectName: "cancel"
                    text: "cancel the build"
                    variant: "destructive"
                }
                Button {
                    objectName: "archive"
                    text: "archive"
                    disabledReason: "Archive needs at least one done job."
                }
            }
        }
    }

    Component {
        id: sheetComponent

        // Tiles with one or two patterns in each status, wide messages, and a status region with its buttons, on the
        // current theme's ground.
        Rectangle {
            width: 980
            height: column.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Column {
                id: column

                x: Tokens.spaceL
                y: Tokens.spaceL
                width: parent.width - 2 * Tokens.spaceL
                spacing: Tokens.spaceL

                Grid {
                    columns: 5
                    spacing: Tokens.spaceL

                    Repeater {
                        model: ["", "info", "success", "warning", "error"]

                        delegate: Tile {
                            required property string modelData

                            status: modelData

                            Stat {
                                value: "1"
                                label: "tokens, for every platform"
                            }
                        }
                    }

                    Repeater {
                        model: ["", "info", "success", "warning", "error"]

                        delegate: Tile {
                            required property string modelData

                            status: modelData

                            Stat {
                                value: "60%"
                                label: "imported"
                            }
                            Progress {
                                width: parent.width
                                value: 0.6
                            }
                        }
                    }

                    Repeater {
                        model: ["", "info", "success", "warning", "error"]

                        delegate: Tile {
                            required property string modelData

                            status: modelData

                            TileMessage {
                                text: testCase.longSentence
                            }
                        }
                    }
                }

                Row {
                    spacing: Tokens.spaceL

                    Tile {
                        columns: 2

                        TileMessage {
                            kicker: "nightly import"
                            text: "It has run every night this month without a retry; the next run starts tonight at two."
                            facts: "30 of 30 runs"
                        }
                    }

                    Tile {
                        columns: 2
                        rows: 2
                        status: "warning"

                        TileMessage {
                            kicker: "review"
                            text: testCase.longSentence
                            facts: "2 open · oldest 3 days"
                        }
                    }
                }

                StatusRegion {
                    width: 600
                    kicker: "nightly build"
                    status: "info"
                    word: "running"
                    figures: [
                        Stat {
                            value: "412"
                            label: "tests run"
                        },
                        Stat {
                            value: "3"
                            label: "failed"
                        },
                        Stat {
                            value: "6 min"
                            label: "left"
                        }
                    ]

                    Button {
                        text: "pause"
                    }
                    Button {
                        text: "cancel the build"
                        variant: "destructive"
                    }
                    Button {
                        text: "archive"
                        disabledReason: "Archive needs at least one done job."
                    }
                }
            }
        }
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function test_a_stat_pair_is_a_large_tabular_number_over_its_words() {
        const tile = createTemporaryObject(statTile, testCase);
        const stat = findChild(tile, "stat");
        waitForItemPolished(stat);
        const number = findChild(stat, "number");
        const words = findChild(stat, "words");
        compare(number.font.pixelSize, Tokens.fluid(Tokens.fontSizeXxl, stat.placeWidth));
        compare(number.font.weight, Tokens.fontWeightMedium);
        compare(number.font.features, { "tnum": 1 });
        compare(number.lineHeight, Geometry.statLineHeight);
        compare(words.font.pixelSize, Tokens.fontSizeXs);
        compare(words.y, number.height, "in a tile the words sit right under the number");
        stat.placeWidth = 4000;
        compare(number.font.pixelSize, Tokens.fontSizeXxl.max, "the number is fluid with the place");
    }

    function test_in_a_tile_a_stat_takes_the_content_width_and_its_words_wrap_inside_it() {
        const tile = createTemporaryObject(statTile, testCase);
        const stat = findChild(tile, "stat");
        const words = findChild(stat, "words");
        stat.label = "tokens, for every platform";
        compare(stat.width, tile.width - 2 * Geometry.tilePadding);
        verify(words.lineCount > 1, "the words wrap");
        verify(words.mapToItem(tile, words.contentWidth, 0).x <= tile.width - Geometry.tilePadding, "within the content width");
    }

    function test_in_a_tile_the_words_take_the_tiles_text_colour_in_every_status() {
        for (const status of ["", "info", "success", "warning", "error"]) {
            const tile = createTemporaryObject(statTile, testCase, { status: status });
            const words = findChild(findChild(tile, "stat"), "words");
            compare(words.color, Tokens.color.textPrimary, status || "neutral");
            compare(words.lineHeight, Tokens.lineHeightCompact);
        }
    }

    function test_among_figures_the_words_are_secondary_and_space_xs_below() {
        const figures = createTemporaryObject(figuresComponent, testCase, { width: 600 });
        const stat = findChild(figures, "first");
        const words = findChild(stat, "words");
        verify(stat.inFigures);
        compare(words.color, Tokens.color.textContrastHigh, "on the ground");
        compare(words.lineHeight, Tokens.lineHeightBody);
        compare(words.y, findChild(stat, "number").height + Tokens.spaceXs);
        const tile = createTemporaryObject(statTile, testCase, { status: "error" });
        figures.parent = tile;
        compare(words.color, Tokens.color.textPrimary, "on a status fill only the primary text colour clears AA");
    }

    function test_figures_stand_space_xl_apart_and_wrap_space_m_below_exactly_where_the_row_is_full() {
        const figures = createTemporaryObject(figuresComponent, testCase, { width: 2000 });
        waitForItemPolished(figures);
        const [first, second, third] = ["first", "second", "third"].map(name => findChild(figures, name));
        const widths = [first, second, third].map(stat => stat.implicitWidth - stat.rightPadding);
        compare(second.x, widths[0] + Tokens.spaceXl);
        compare(third.x, widths[0] + widths[1] + 2 * Tokens.spaceXl);
        compare(figures.implicitWidth, widths[0] + widths[1] + widths[2] + 2 * Tokens.spaceXl);
        figures.width = figures.implicitWidth;
        waitForItemPolished(figures);
        compare(third.y, 0, "three figures fill the row exactly");
        figures.width -= 1;
        waitForItemPolished(figures);
        compare(third.x, 0);
        compare(third.y, first.height + Tokens.spaceM);
    }

    function test_progress_in_a_tile_draws_in_the_tiles_text_colour_without_a_number() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            for (const status of ["", "info", "success", "warning", "error"]) {
                const tile = createTemporaryObject(progressTile, testCase, { status: status });
                const progress = findChild(tile, "progress");
                const fill = findChild(progress, "fill");
                const track = fill.parent.children[0];
                compare(fill.color, Tokens.color.textPrimary, `${theme} ${status || "neutral"}`);
                compare(track.color, Tokens.color.textPrimary);
                compare(track.opacity, Geometry.progressTrackOpacity);
                compare(fill.width, fill.parent.width * 0.6);
                verify(!findChild(progress, "percent").parent.visible, "the stat pair states the fraction");
            }
        }
    }

    function test_a_message_ends_in_an_ellipsis_after_four_lines_and_is_still_read_whole() {
        const tile = createTemporaryObject(messageTile, testCase);
        const message = findChild(tile, "message");
        const sentence = findChild(message, "sentence");
        message.text = longSentence;
        compare(sentence.lineCount, Geometry.tileMessageLines);
        verify(sentence.truncated);
        compare(sentence.Accessible.name, longSentence);
        compare(sentence.elide, Text.ElideRight);
        message.text = "Nothing waits.";
        compare(sentence.lineCount, 1);
        verify(!sentence.truncated);
    }

    function test_a_message_on_a_wide_tile_runs_to_six_lines() {
        for (const [columns, rows] of [[2, 1], [2, 2]]) {
            const tile = createTemporaryObject(messageTile, testCase, { columns: columns, rows: rows });
            const sentence = findChild(findChild(tile, "message"), "sentence");
            findChild(tile, "message").text = `${longSentence} ${longSentence}`;
            compare(sentence.lineCount, Geometry.tileMessageLinesWide, `${columns}×${rows}`);
            verify(sentence.truncated);
        }
        const tile = createTemporaryObject(messageTile, testCase, { columns: 2 });
        tile.columns = 1;
        findChild(tile, "message").text = longSentence;
        compare(findChild(findChild(tile, "message"), "sentence").lineCount, Geometry.tileMessageLines);
    }

    function test_a_message_is_a_sentence_in_s_with_its_kicker_above_and_its_facts_below() {
        const tile = createTemporaryObject(messageTile, testCase, { status: "success" });
        const message = findChild(tile, "message");
        message.text = "It has run every night this month.";
        waitForItemPolished(message);
        const [kicker, sentence, facts] = ["kicker", "sentence", "facts"].map(name => findChild(message, name));
        compare(sentence.font.pixelSize, Tokens.fontSizeS);
        compare(sentence.lineHeight, Tokens.lineHeightCompact);
        compare(sentence.color, Tokens.color.textPrimary);
        compare(sentence.y, kicker.y + kicker.height + Tokens.spaceS, "the kicker names it above");
        compare(facts.y, sentence.y + sentence.height + Tokens.spaceS, "the facts follow below");
        compare(kicker.lineHeight, Tokens.lineHeightCompact);
        compare(facts.lineHeight, Tokens.lineHeightCompact);
        compare(facts.color, Tokens.color.textPrimary, "secondary text on a status fill");
        message.kicker = "";
        message.facts = "";
        verify(!kicker.visible && !facts.visible);
    }

    function test_a_tile_with_more_than_three_patterns_warns() {
        ignoreWarning(/Tile: 4 content patterns; a tile combines at most two or three/);
        const tile = createTemporaryObject(crowdedTile, testCase, { status: "info" });
        compare(tile.patterns, 4, "the status word is one of them");
    }

    function test_a_crowded_tile_warns_once_its_content_has_arrived() {
        failOnWarning(/Tile: 4 content patterns/);
        ignoreWarning(/Tile: 5 content patterns/);
        createTemporaryObject(crowdedTile, testCase, { status: "info", overfull: true });
    }

    function test_a_fourth_pattern_added_later_warns() {
        const tile = createTemporaryObject(crowdedTile, testCase);
        compare(tile.patterns, 3);
        ignoreWarning(/Tile: 4 content patterns/);
        createTemporaryObject(statComponent, findChild(tile, "stat").parent);
        compare(tile.patterns, 4);
    }

    function test_three_patterns_or_fewer_do_not_warn() {
        failOnWarning(/content patterns/);
        compare(createTemporaryObject(crowdedTile, testCase).patterns, 3);
        compare(createTemporaryObject(progressTile, testCase, { status: "warning" }).patterns, 3);
        compare(createTemporaryObject(messageTile, testCase).patterns, 1);
    }

    function test_a_status_region_has_no_fill_no_press_and_no_focus() {
        const ground = createTemporaryObject(regionComponent, testCase);
        const region = findChild(ground, "region");
        waitForRendering(ground);
        const image = grabImage(ground);
        verify(Qt.colorEqual(image.pixel(ground.width - 2, region.height / 2), Tokens.color.bg), "the ground shows through");
        verify(!region.activeFocusOnTab);
        mouseClick(findChild(region, "figures"));
        compare(findChild(ground, "beneath").presses, 1, "a press on the figures is not the region's");
        verify(!region.activeFocus);
        compare(region.Accessible.role, Accessible.Grouping);
        compare(region.Accessible.name, "nightly build · running", "the whole kicker line names it");
    }

    function test_its_status_is_a_tag_in_the_kicker() {
        const region = findChild(createTemporaryObject(regionComponent, testCase), "region");
        const kicker = findChild(region, "kicker");
        const tag = findChild(region, "tag");
        compare(kicker.text, "nightly build · ");
        compare(tag.status, "info");
        compare(tag.word, "running");
        compare(tag.x, kicker.width);
        const word = findChild(tag, "word");
        compare(word.mapToItem(region, 0, word.baselineOffset).y, kicker.mapToItem(region, 0, kicker.baselineOffset).y, "on the kicker's baseline");
    }

    function test_its_figures_stand_on_the_ground_with_secondary_words() {
        const region = findChild(createTemporaryObject(regionComponent, testCase), "region");
        const figures = findChild(region, "figures");
        compare(figures.children.length, 2);
        compare(findChild(figures.children[0], "words").color, Tokens.color.textContrastHigh);
    }

    function test_its_actions_stand_space_s_apart() {
        const region = findChild(createTemporaryObject(regionComponent, testCase), "region");
        const actions = findChild(region, "actions");
        const [pause, cancel] = ["pause", "cancel"].map(name => findChild(actions, name));
        waitForItemPolished(actions.children[0]);
        compare(cancel.x, pause.x + pause.width + Tokens.spaceS);
        compare(cancel.y, pause.y);
    }

    function test_why_a_button_cannot_act_takes_the_rest_of_the_row() {
        const region = findChild(createTemporaryObject(regionComponent, testCase), "region");
        const actions = findChild(region, "actions");
        const archive = findChild(actions, "archive");
        const why = findChild(actions, "why");
        waitForItemPolished(actions.children[0]);
        verify(!findChild(archive, "why").visible, "the row says why, not the button");
        compare(archive.Accessible.description, "Archive needs at least one done job.");
        verify(why.visible);
        compare(why.text, "Archive needs at least one done job.");
        compare(why.x, archive.x + archive.width + Tokens.spaceS);
        compare(why.x + why.width, actions.width);
        verify(actions.width - why.x >= Geometry.whyBasis);
        archive.disabledReason = "";
        verify(!why.visible);
    }

    function test_a_hidden_button_gives_the_row_no_reason() {
        const actions = findChild(findChild(createTemporaryObject(regionComponent, testCase), "region"), "actions");
        const why = findChild(actions, "why");
        verify(why.visible);
        findChild(actions, "archive").visible = false;
        compare(actions.why, "");
        verify(!why.visible);
    }

    function test_why_takes_a_row_of_its_own_when_less_than_its_basis_is_left() {
        const ground = createTemporaryObject(regionComponent, testCase);
        const region = findChild(ground, "region");
        const actions = findChild(region, "actions");
        const archive = findChild(actions, "archive");
        const why = findChild(actions, "why");
        waitForItemPolished(actions.children[0]);
        compare(Geometry.whyBasis, 12 * 16, "12rem");
        ground.width = archive.x + archive.width + Tokens.spaceS + Geometry.whyBasis - 1;
        waitForItemPolished(actions.children[0]);
        compare(archive.y, 0, "the buttons still fit on one row");
        compare(why.x, 0);
        compare(why.width, actions.width);
        compare(why.y, actions.children[0].height + Tokens.spaceS);
        compare(actions.height, why.y + why.height);
    }

    function test_a_button_outside_an_actions_row_still_says_why_beside_itself() {
        const button = createTemporaryObject(buttonComponent, testCase);
        verify(findChild(button, "why").visible);
    }

    // The patterns follow the one current theme and density, so the sheet is drawn once per pair.
    function test_contact_sheet_of_patterns_and_a_status_region_in_both_themes_and_densities() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                waitForRendering(sheet);
                grabImage(sheet).save(`patterns-sheet-${theme}-${density}.png`);
                verify(sheet.height > 0, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
