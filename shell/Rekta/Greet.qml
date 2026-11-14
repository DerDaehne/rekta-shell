pragma Singleton
import QtQuick

// News on several tiles comes one after another (motion.md, "Live tile news"; rekta.js greet(), :4131–4151): the
// tiles, and the bar controls, with news within duration-moderate of the first show it in reading order on the screen,
// duration-greet apart, four steps at most, the rest with the fourth. Each piece of news starts at once; those told
// before the next frame are ordered then, and each one's motion waits for its step. Each window counts on its own, as
// rekta-core does (core/src/anim.c:335–336, :352–354): the bar and the Start never wait for one another. Under reduced
// motion both durations are 0, so nothing waits.
QtObject {
    // The clock, in ms; a test sets its own.
    property var now: () => Date.now()
    // Per window: when the first of the news within duration-moderate came (`since`), and how many have come (`told`).
    property var runs: new Map()
    property var telling: []

    // `news` is an Item with the news, which takes its step through waitFor(ms).
    function join(news: Item) {
        if (telling.includes(news))
            return;
        telling.push(news);
        if (telling.length === 1)
            Qt.callLater(settle);
    }

    // Reading order on the screen, by row and then from the leading edge, as rekta-core orders news (core/src/anim.c:337–339).
    function settle() {
        const at = now();
        const parts = telling.filter(news => (news as Item) !== null).map(news => {
            const corner = news.mapToItem(null, 0, 0);
            return { x: corner.x, y: corner.y, news };
        });
        telling = [];
        for (const part of Turnstile.inReadingOrder(parts)) {
            const run = runOf(part.news.Window.window, at);
            part.news.waitFor(Math.max(0, run.since + Math.min(run.told, Geometry.greetSteps) * Tokens.durationGreet - at));
            run.told++;
        }
    }

    // The window's run of news: a new one once more than duration-moderate has passed since its first.
    function runOf(window: var, at: real): var {
        const run = runs.get(window);
        if (run && at - run.since <= Tokens.durationModerate)
            return run;
        const fresh = { since: at, told: 0 };
        runs.set(window, fresh);
        return fresh;
    }
}
