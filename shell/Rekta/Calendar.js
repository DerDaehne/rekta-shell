.pragma library
.import QtQml as QtQml

// Dates for the clock and the month, as pure functions of a Date and a QML Locale.

// How long until the minute changes: the clock wakes once a minute, never more often.
function untilNextMinute(date) {
    return 60000 - (date.getSeconds() * 1000 + date.getMilliseconds());
}

// The time as the locale writes it short: "14:32", "2:32 PM".
function timeWords(date, locale) {
    return date.toLocaleTimeString(locale, QtQml.Locale.ShortFormat);
}

// How long ago, in Rekta's German words (strings.de.js: justNow, minutesAgo, at): "gerade eben", "vor 4 min", then the
// time of day, and the day too from yesterday on. A minute is the finest step, as it is renewed once a minute.
function ago(date, now, locale) {
    const minutes = Math.floor((now - date) / 60000);
    if (minutes < 1)
        return "gerade eben";
    if (minutes < 60)
        return `vor ${minutes} min`;
    const time = `um ${timeWords(date, locale)}`;
    return sameDay(date, now) ? time : `${dateWords(date, locale)} ${time}`;
}

// A day or month name as a lowercase word, without the abbreviation's dot: "di", "okt".
function word(name) {
    return name.replace(/\.$/, "").toLowerCase();
}

// Weekday, day and month, in the order the locale's long date has them: "di 20. okt", "tue oct 20", "tue 20 oct".
function dateWords(date, locale) {
    const pattern = locale.dateFormat(QtQml.Locale.LongFormat);
    const dayAt = pattern.search(/(^|[^d])d{1,2}([^d]|$)/);
    const monthAt = pattern.indexOf("M");
    const day = /(^|[^d])d{1,2}\./.test(pattern) ? `${date.getDate()}.` : `${date.getDate()}`;
    const month = word(locale.monthName(date.getMonth(), QtQml.Locale.ShortFormat));
    const weekday = word(locale.dayName(date.getDay(), QtQml.Locale.ShortFormat));
    return monthAt >= 0 && monthAt < dayAt ? `${weekday} ${month} ${day}` : `${weekday} ${day} ${month}`;
}

// The month's name and year as a lowercase heading: "oktober 2026".
function monthTitle(date, locale) {
    return `${locale.standaloneMonthName(date.getMonth(), QtQml.Locale.LongFormat).toLowerCase()} ${date.getFullYear()}`;
}

function addDays(date, days) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

// The same day some months on, or the month's last day where it is shorter.
function addMonths(date, months) {
    const last = new Date(date.getFullYear(), date.getMonth() + months + 1, 0).getDate();
    return new Date(date.getFullYear(), date.getMonth() + months, Math.min(date.getDate(), last));
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

// The Monday that starts the six weeks showing the month, as rekta-core's month always starts its weeks.
function gridStart(date) {
    const first = new Date(date.getFullYear(), date.getMonth(), 1);
    return addDays(first, -((first.getDay() + 6) % 7));
}

// How many weeks, Monday first, the month touches: 4 to 6.
function weekCount(date) {
    const lead = (monthStart(date).getDay() + 6) % 7;
    return Math.ceil((lead + monthEnd(date).getDate()) / 7);
}

// ISO 8601 week number: the week belongs to the year that holds its Thursday.
function weekNumber(date) {
    const thursday = addDays(date, 3 - (date.getDay() + 6) % 7);
    const yearStart = new Date(thursday.getFullYear(), 0, 1);
    // Local midnights are 23 or 25 hours apart across a daylight saving change, so round to whole days.
    const dayOfYear = Math.round((thursday - yearStart) / 86400000);
    return Math.floor(dayOfYear / 7) + 1;
}

function monthStart(date) {
    return new Date(date.getFullYear(), date.getMonth(), 1);
}

function monthEnd(date) {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0);
}
