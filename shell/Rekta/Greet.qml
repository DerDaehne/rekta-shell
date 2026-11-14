pragma Singleton
import QtQuick

// News on several tiles comes one after another (motion.md, "Live tile news"; rekta.js greet(), :4131–4151): the
// tiles, and the bar controls, with news within duration-moderate of the first show it in reading order on the screen,
// duration-greet apart, four steps at most, the rest with the fourth. Each piece of news starts at once; those told
// before the next frame are ordered then, and each one's motion waits for its step. Under reduced motion both durations
// are 0, so nothing waits.
QtObject {
    // The clock, in ms; a test sets its own.
    property var now: () => Date.now()
    // When the first of the news within duration-moderate came, and how many have come since.
    property double since: -Infinity
    property int told: 0
    property var telling: []

    // `news` is an Item with the news, which takes its step through waitFor(ms).
    function join(news: Item) {
        if (telling.includes(news))
            return;
        telling.push(news);
        if (telling.length === 1)
            Qt.callLater(settle);
    }

    // Reading order on the screen, by row and then from the leading edge, as rekta-core orders news (core/src/anim.c:333–340).
    function settle() {
        const at = now();
        if (at - since > Tokens.durationModerate) {
            since = at;
            told = 0;
        }
        const parts = telling.filter(news => (news as Item) !== null).map(news => {
            const corner = news.mapToItem(null, 0, 0);
            return { x: corner.x, y: corner.y, news };
        });
        telling = [];
        for (const part of Turnstile.inReadingOrder(parts)) {
            part.news.waitFor(Math.max(0, since + Math.min(told, Geometry.greetSteps) * Tokens.durationGreet - at));
            told++;
        }
    }
}
