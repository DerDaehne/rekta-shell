.pragma library
.import QtQml as QtQml

// Dates for the clock and the month, as pure functions of a Date and a QML Locale.

const dayMs = 24 * 60 * 60 * 1000;

// How long until the minute changes: the clock wakes once a minute, never more often.
function untilNextMinute(date) {
    return 60000 - (date.getSeconds() * 1000 + date.getMilliseconds());
}

// The time as the locale writes it short: "14:32", "2:32 PM".
function timeWords(date, locale) {
    return date.toLocaleTimeString(locale, QtQml.Locale.ShortFormat);
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

// The first day of the six weeks that show the month, the week starting on the locale's first day (0 is Sunday).
function gridStart(date, firstDayOfWeek) {
    const first = new Date(date.getFullYear(), date.getMonth(), 1);
    return addDays(first, -((first.getDay() - firstDayOfWeek + 7) % 7));
}

// The ISO 8601 week of a day: the week of its Thursday, counted in that Thursday's year.
function isoWeek(date) {
    const thursday = addDays(date, 3 - (date.getDay() + 6) % 7);
    const january1 = new Date(thursday.getFullYear(), 0, 1);
    return Math.floor(Math.round((thursday - january1) / dayMs) / 7) + 1;
}

// A row that starts on another weekday than Monday holds most of the ISO week its Thursday is in.
function rowWeek(rowStart) {
    return isoWeek(addDays(rowStart, (4 - rowStart.getDay() + 7) % 7));
}
