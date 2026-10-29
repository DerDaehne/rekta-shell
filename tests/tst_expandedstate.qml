import QtQuick
import QtTest
import Rekta

TestCase {
    name: "ExpandedState"

    Item {
        id: announced
    }

    ExpandedState {
        id: expansion

        target: announced
    }

    function test_changing_the_state_breaks_nothing_where_qt_has_no_expanded_state() {
        expansion.expanded = true;
        compare(expansion.expanded, true);
        expansion.expanded = false;
        compare(expansion.expanded, false);
    }

    function test_where_qt_knows_it_the_target_is_expandable_and_expanded_follows_the_state() {
        if (!("expanded" in announced.Accessible))
            skip("this Qt has no Accessible.expanded");
        verify(announced.Accessible.expandable);
        expansion.expanded = true;
        verify(announced.Accessible.expanded);
        expansion.expanded = false;
        verify(!announced.Accessible.expanded);
    }
}
