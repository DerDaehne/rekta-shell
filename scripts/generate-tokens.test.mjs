// Regression tests for scripts/generate-tokens.mjs: tokens it cannot map stop it instead of vanishing silently.
//   REKTA_DESIGN_DIST=<rekta-design dist dir> node --test scripts/generate-tokens.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const generator = join(dirname(fileURLToPath(import.meta.url)), 'generate-tokens.mjs');
const dist = process.env.REKTA_DESIGN_DIST;
assert.ok(dist, 'REKTA_DESIGN_DIST must point at Rekta Design dist/');
const originalTokens = JSON.parse(readFileSync(join(dist, 'rekta.tokens.json'), 'utf8'));
const originalIcons = JSON.parse(readFileSync(join(dist, 'rekta.icons.json'), 'utf8'));

// Runs the generator on changed copies of the tokens and icons; returns its exit status, error output and files.
function generate(change) {
	const dir = mkdtempSync(join(tmpdir(), 'generate-tokens-'));
	try {
		const tokens = structuredClone(originalTokens);
		const icons = structuredClone(originalIcons);
		change(tokens, icons);
		writeFileSync(join(dir, 'rekta.tokens.json'), JSON.stringify(tokens));
		writeFileSync(join(dir, 'rekta.icons.json'), JSON.stringify(icons));
		const rekta = join(dir, 'shell', 'Rekta');
		mkdirSync(rekta, { recursive: true });
		const run = spawnSync(process.execPath, [generator, dir, join(dir, 'shell')], { encoding: 'utf8' });
		const file = (name) => (run.status === 0 ? readFileSync(join(rekta, name), 'utf8') : '');
		return { status: run.status, stderr: run.stderr, tokens: file('Tokens.qml'), icons: file('IconData.js') };
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
}

function assertRefused(change, message) {
	const { status, stderr } = generate(change);
	assert.equal(status, 1);
	assert.match(stderr, message);
}

test('the unchanged tokens and icons generate the module', () => {
	const { status, tokens, icons } = generate(() => {});
	assert.equal(status, 0);
	assert.match(tokens, /pragma Singleton/);
	assert.match(icons, /\.pragma library/);
});

test('a new token group stops the generator', () => {
	assertRefused((t) => (t.elevation = { 'shadow-s': 2 }), /no mapping for token group\(s\): elevation/);
});

test('a new kind of typography token stops the generator', () => {
	assertRefused((t) => (t.typography['letter-spacing-kicker'] = 0.02), /typography: no mapping for letter-spacing-kicker/);
});

test('a third theme stops the generator', () => {
	assertRefused((t) => (t.themes.sepia = t.themes.light), /themes: expected light, dark, got/);
});

test('a third density stops the generator', () => {
	assertRefused((t) => (t.densities.spacious = t.densities.comfortable), /densities: expected comfortable, compact, got/);
});

test('themes with different tokens stop the generator', () => {
	assertRefused((t) => delete t.themes.dark.glass, /Colours: the modes do not share the same tokens/);
});

test('a malformed colour stops the generator', () => {
	assertRefused((t) => (t.themes.light.bg = 'white'), /not a colour: white/);
});

test('a malformed easing stops the generator', () => {
	assertRefused((t) => (t.motion['ease-in'] = [0, 0, 1]), /not a cubic-bezier/);
});

test('a name QML reads as a signal handler stops the generator', () => {
	assertRefused((t) => {
		t.themes.light['on-surface'] = '#000000';
		t.themes.dark['on-surface'] = '#ffffff';
	}, /on-surface: QML would read onSurface as a signal handler/);
});

test('two tokens on one QML name stop the generator', () => {
	assertRefused((t) => (t.timing['duration-short'] = 250), /tokens collide on: durationShort/);
});

test('a new kind of icon shape stops the generator', () => {
	assertRefused((_, icons) => icons.icons.check.push({ tag: 'rect', attrs: { x: '1', y: '1', width: '2', height: '2' } }), /no mapping for icon shape <rect>/);
});

test('a malformed circle stops the generator', () => {
	assertRefused((_, icons) => (icons.icons.clock[0].attrs.r = 'big'), /not a circle/);
});

test('a circle becomes two arcs of path data', () => {
	const { icons } = generate((_, set) => (set.icons.probe = [{ tag: 'circle', attrs: { cx: '10', cy: '10', r: '7' } }]));
	assert.match(icons, /"probe": \{ stroke: "M3 10a7 7 0 1 0 14 0a7 7 0 1 0 -14 0z", fill: "" \}/);
});

test('a leading relative move stays where it was drawn once it follows another shape', () => {
	const { icons } = generate((_, set) => {
		set.icons.probe = [{ tag: 'circle', attrs: { cx: '9', cy: '9', r: '5.5' } }, { tag: 'path', attrs: { d: 'm13 13 4 4' } }];
	});
	assert.match(icons, /"probe": \{ stroke: "M3\.5 9a[^"]*z M13 13 l 4 4"/);
});

test('solid shapes go into the fill path, outlines into the stroke path', () => {
	const { icons } = generate(() => {});
	assert.match(icons, /"theme": \{ stroke: "M4 10a6[^"]*z", fill: "M10 4a6 6 0 0 1 0 12z" \}/);
});

test('an icon attribute without a mapping stops the generator', () => {
	assertRefused((_, icons) => (icons.icons.close[0].attrs.transform = 'rotate(45)'), /close: no mapping for <path> attribute\(s\) transform/);
	assertRefused((_, icons) => (icons.icons.check[0].attrs['stroke-width'] = '2'), /check: no mapping for <path> attribute\(s\) stroke-width/);
});

test('a line cap or join the icon cannot draw stops the generator', () => {
	assertRefused((_, icons) => (icons.lineCap = 'triangle'), /no mapping for line cap triangle/);
	assertRefused((_, icons) => (icons.lineJoin = 'arcs'), /no mapping for line join arcs/);
});

test('the tile unit is the product value whatever Rekta gives', () => {
	const { tokens } = generate((t) => (t.size['tile-unit'] = 99));
	assert.match(tokens, /property real tileUnit: 170\n/);
});
