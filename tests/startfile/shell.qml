import QtQml
import Quickshell
import Quickshell.Io
import Settings

// One writer of start.json, the shell or the settings app, driven by tests/startfile.sh over IPC.
Scope {
    StartFile {
        id: start

        // What a pin of REKTA_EARLY_PIN before the file's first load returned, "" without one.
        property string earlyPin: ""

        Component.onCompleted: {
            const early = Quickshell.env("REKTA_EARLY_PIN") ?? "";
            if (early !== "")
                earlyPin = String(pin(early));
        }
    }

    // REKTA_FOLLOWERS more readers of the file, none of them writing: each reads at a moment of its own, so together
    // they meet a change at many points of a read.
    Instantiator {
        id: followers

        model: Number(Quickshell.env("REKTA_FOLLOWERS") ?? 0)
        delegate: StartFile {}
    }

    IpcHandler {
        target: "start"

        function earlyPin(): string {
            return start.earlyPin;
        }

        function settled(): bool {
            return start.settled;
        }

        // The list, or "behind" while a follower shows another one.
        function list(): string {
            const own = JSON.stringify(start.list);
            for (let i = 0; i < followers.count; ++i) {
                if (JSON.stringify((followers.objectAt(i) as StartFile).list) !== own)
                    return "behind";
            }
            return own;
        }

        function fault(): string {
            return start.fault;
        }

        function pin(id: string): bool {
            return start.pin(id);
        }

        // Two changes at once, without the event loop between them.
        function pinBoth(first: string, second: string): bool {
            return start.pin(first) && start.pin(second);
        }

        function unpin(index: int): bool {
            return start.unpin(index);
        }
    }
}
