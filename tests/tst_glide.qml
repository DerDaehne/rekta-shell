pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "Glide.js" as Glide

TestCase {
    id: testCase

    name: "Glide"
    when: windowShown

    readonly property int duration: 250
    readonly property easingCurve curve: ({ type: Easing.OutCubic })

    Component {
        id: movingComponent

        Item {
            Behavior on x {
                NumberAnimation {
                    duration: testCase.duration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // What a busy machine does to a test: the thread stops for a while in the midst of a tick.
    function stallFor(ms: int) {
        const until = Date.now() + ms;
        while (Date.now() < until)
            continue;
    }

    function test_a_step_stamped_long_after_its_tick_began_still_counts_at_that_tick() {
        const ticks = Glide.ticks(testCase);
        const moving = createTemporaryObject(movingComponent, testCase);
        let stalled = false;
        moving.xChanged.connect(() => {
            if (stalled || moving.x < 90)
                return;
            stalled = true;
            stallFor(testCase.duration / 2);
        });
        const steps = Glide.record(moving, "x");
        const since = Date.now();
        moving.x = 100;
        tryVerify(() => moving.x === 100, testCase.duration * 4, "it ends exactly on 100");
        verify(stalled, "the step past 90 was stamped late");
        const stray = Glide.strayOf([{ steps, from: 0, to: 100 }], testCase.duration, testCase.curve, since, ticks);
        verify(stray < 0.06, `it still follows the curve over its duration: off by ${stray}`);
    }
}
