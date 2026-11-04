import QtQuick

// A status region (tiles.md, "Status region"): the figures of the one thing a place is about, with the controls that
// act on it below, on the ground. It is not a tile: no fill, no press, no focus; its status is a tag in the kicker.
// It takes the width it is given, like a block. Its parts stand a section's space-m apart, the figures space-s under
// the kicker as in a tile (`.rk-status-region`, rekta.css:115–116).
Column {
    id: region

    property string kicker
    // info | success | warning | error, or "" for none (idle)
    property string status: ""
    // The tag's word, when the region's own word says the status better ("running"); without a word there is no tag.
    property alias word: tag.word
    // The Stat pairs, or other figures as wide as the region.
    property alias figures: figuresRow.data
    default property alias controls: actionsRow.controls

    spacing: Tokens.spaceM
    Accessible.role: Accessible.Grouping
    // The whole kicker line names it, the tag's word included (aria-labelledby in tiles.md).
    Accessible.name: tag.visible ? `${kicker} · ${tag.word}` : kicker

    Column {
        width: region.width
        spacing: Tokens.spaceS

        // `<p class="rk-kicker">nightly build · <span class="rk-tag">running</span></p>` (tiles.md)
        Item {
            width: region.width
            height: kickerText.height

            Kicker {
                id: kickerText

                objectName: "kicker"
                width: tag.visible ? implicitWidth : region.width
                text: tag.visible ? `${region.kicker} · ` : region.kicker
            }

            StatusTag {
                id: tag

                objectName: "tag"
                x: kickerText.width
                anchors.baseline: kickerText.baseline
                visible: word !== ""
                status: region.status
            }
        }

        Figures {
            id: figuresRow

            objectName: "figures"
            width: region.width
        }
    }

    Actions {
        id: actionsRow

        objectName: "actions"
        width: region.width
    }
}
