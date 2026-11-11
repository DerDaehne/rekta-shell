import QtQml
import Quickshell
import Quickshell.Io
import Settings

// One writer of start.json, the shell or the settings app, driven by tests/startfile.sh over IPC.
Scope {
    StartFile {
        id: start
    }

    IpcHandler {
        target: "start"

        function settled(): bool {
            return start.settled;
        }

        function list(): string {
            return JSON.stringify(start.list);
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
