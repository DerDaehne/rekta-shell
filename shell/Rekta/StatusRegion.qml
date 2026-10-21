import QtQuick

// A status region (tiles.md, "Status region"): the figures of the one thing a place is about, with the controls that
// act on it below, on the ground. It is not a tile: no fill, no press, no focus; its status is a tag in the kicker.
// It takes the width it is given, like a block. Its parts stand without space between them, as rekta.css sets none.
Column {
    id: region

    property string kicker
    // info | success | warning | error, or "" for none (idle)
    property string status: ""
    // The tag's word, when the region's own word says the status better ("running").
    property alias word: tag.word
    // The Stat pairs.
    property alias figures: figuresRow.data
    default property alias controls: actionsRow.controls

    Accessible.role: Accessible.Grouping
    Accessible.name: kicker

    // `<p class="rk-kicker">nightly build · <span class="rk-tag">running</span></p>` (tiles.md)
    Item {
        width: region.width
        height: kickerText.height

        Kicker {
            id: kickerText

            objectName: "kicker"
            text: `${region.kicker} · `
        }

        StatusTag {
            id: tag

            objectName: "tag"
            x: kickerText.width
            anchors.baseline: kickerText.baseline
            status: region.status
        }
    }

    Figures {
        id: figuresRow

        objectName: "figures"
        width: region.width
    }

    Actions {
        id: actionsRow

        objectName: "actions"
        width: region.width
    }
}
