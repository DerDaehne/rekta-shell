import QtQuick

// The controls of a region in one row that wraps, space-s apart (rekta.css:232). A button that cannot act says why
// after the controls: the reason takes the rest of the row, or a row of its own when less than its basis is left
// (`.rk-actions > .rk-why { flex: 1 1 12rem }`, :290). It takes the width it is given, like a block.
Item {
    id: actions

    default property alias controls: row.data
    // Why the buttons that cannot act now cannot, in their order.
    readonly property string why: {
        const reasons = [];
        for (const control of row.children) {
            const button = control as Button;
            if (button?.visible && button.disabledReason !== "")
                reasons.push(button.disabledReason);
        }
        return reasons.join(" ");
    }

    implicitHeight: hint.visible ? Math.max(row.height, hint.y + hint.height) : row.height

    Flow {
        id: row

        width: actions.width
        spacing: Tokens.spaceS
    }

    // ponytail: the reasons share one hint after the last control; rekta.js disable() puts one after each control.
    Hint {
        id: hint

        readonly property Item last: {
            let last = null;
            for (const control of row.children) {
                // A Repeater stands among the controls it makes and shows nothing.
                if (control.visible && !(control instanceof Repeater))
                    last = control;
            }
            return last;
        }
        readonly property real after: last ? last.x + last.width + Tokens.spaceS : 0
        readonly property bool beside: last !== null && actions.width - after >= Geometry.whyBasis

        objectName: "why"
        visible: actions.why !== ""
        text: actions.why
        x: beside ? after : 0
        width: actions.width - x
        // Centred on its line, as `align-items: center`; a reason taller than the controls does not recentre them.
        y: beside ? last.y + Math.max(0, (last.height - height) / 2) : row.height + Tokens.spaceS
    }
}
