pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import DBusCounterpart
import Notices
import Rekta
import "../shell/services"

TestCase {
    id: testCase

    name: "NoticeCount"

    readonly property string service: "rekta.Shell"
    readonly property string iface: "rekta.Shell.Notices"
    property NoticeBoard board
    // Every UnseenCountChanged the counterpart heard in this file, and the shells that have owned the name: a shell
    // of an earlier test may still send as its board goes.
    property var heardAll: []
    property var owners: []
    property string owner
    readonly property var heard: heardAll.filter(signal => signal.sender === owner)

    Counterpart {
        id: counterpart

        onHeard: (sender, path, member, signature, values) => testCase.heardAll = [...testCase.heardAll, {
                sender,
                path,
                member,
                signature,
                values
            }]
    }

    FakeNotifications {
        id: fakes
    }

    // Quiet, a notification goes into the list unseen at once, without a toast to wait out.
    Component {
        id: boardComponent

        NoticeBoard {
            toaster: Toaster {}
            quiet: true
        }
    }

    Component {
        id: countComponent

        NoticeCount {
            sessionDesktop: ""
            // The board of a test goes before its count does.
            count: testCase.board?.unseen ?? 0
        }
    }

    function initTestCase() {
        verify(counterpart.listen(iface, "UnseenCountChanged"));
        // A round trip on the counterpart's connection: its subscription has reached the bus.
        counterpart.nameOwner("org.freedesktop.DBus");
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        owner = "";
        board = createTemporaryObject(boardComponent, testCase);
    }

    function exportFor(sessionDesktop) {
        // A count of an earlier test may still hold the name until its deferred destruction has run.
        tryVerify(() => counterpart.nameOwner(service) === "");
        const created = createTemporaryObject(countComponent, testCase, {
            sessionDesktop
        });
        if (sessionDesktop === "rekta") {
            tryVerify(() => counterpart.nameOwner(service) !== "");
            owner = counterpart.nameOwner(service);
            owners = [...owners, owner];
        }
        return created;
    }

    function callCount() {
        let answer = null;
        const store = (signature, values, error) => answer = {
            signature,
            values,
            error
        };
        counterpart.replied.connect(store);
        counterpart.call(service, "/rekta/Shell", iface, "UnseenCount", []);
        tryVerify(() => answer !== null);
        counterpart.replied.disconnect(store);
        return answer;
    }

    function introspect() {
        let xml = null;
        const store = (signature, values) => xml = values[0];
        counterpart.replied.connect(store);
        counterpart.call(service, "/rekta/Shell", "org.freedesktop.DBus.Introspectable", "Introspect", []);
        tryVerify(() => xml !== null);
        counterpart.replied.disconnect(store);
        return xml;
    }

    function test_in_the_rekta_session_unseen_count_answers_the_number_meldungen_shows() {
        exportFor("rekta");
        compare(callCount(), {
            signature: "u",
            values: [0],
            error: ""
        });
        board.arrive(fakes.make({ summary: "anna" }));
        board.arrive(fakes.make({ summary: "bert" }));
        compare(board.unseen, 2);
        compare(callCount().values, [2]);
    }

    function test_each_change_of_the_count_is_sent_as_unseen_count_changed() {
        exportFor("rekta");
        board.arrive(fakes.make({ summary: "anna" }));
        tryVerify(() => heard.length === 1);
        compare(heard[0], {
            sender: owner,
            path: "/rekta/Shell",
            member: "UnseenCountChanged",
            signature: "u",
            values: [1]
        });
        board.listInSight = true;
        tryVerify(() => heard.length === 2);
        compare(heard[1].values, [0], "seeing the list sends zero");
    }

    function test_only_a_number_crosses_the_bus_never_the_words_of_a_notification() {
        exportFor("rekta");
        board.arrive(fakes.make({ summary: "anna", body: "lunch at noon?", appName: "chat" }));
        tryVerify(() => heard.length === 1);
        const answer = callCount();
        for (const values of [heard[0].values, answer.values])
            compare(values, [1]);
        const xml = introspect();
        const start = xml.indexOf(`<interface name="${iface}">`);
        verify(start >= 0, xml);
        const interfaceXml = xml.slice(start, xml.indexOf("</interface>", start));
        compare(interfaceXml.match(/<(method|signal|property) name="[^"]*"/g), [`<method name="UnseenCount"`, `<signal name="UnseenCountChanged"`]);
        compare(interfaceXml.match(/type="[^"]*"/g), [`type="u"`, `type="u"`]);
    }

    function test_outside_the_rekta_session_nothing_is_owned_or_sent() {
        for (const sessionDesktop of ["", "KDE", "plasmawayland"]) {
            exportFor(sessionDesktop).destroy();
            compare(counterpart.nameOwner(service), "", sessionDesktop);
        }
        exportFor("KDE");
        board.arrive(fakes.make({ summary: "anna" }));
        compare(board.unseen, 1);
        counterpart.nameOwner("org.freedesktop.DBus");
        wait(100);
        compare(heardAll.filter(signal => !owners.includes(signal.sender)), []);
    }
}
