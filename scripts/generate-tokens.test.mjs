// Regression tests for scripts/generate-tokens.mjs: tokens it cannot map stop it instead of vanishing silently.
//   REKTA_DESIGN_DIST=<rekta-design dist dir> node --test scripts/generate-tokens.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const generator = join(dirname(fileURLToPath(import.meta.url)), 'generate-tokens.mjs');
const dist = process.env.REKTA_DESIGN_DIST;
assert.ok(dist, 'REKTA_DESIGN_DIST must point at Rekta Design dist/');
const original = JSON.parse(readFileSync(join(dist, 'rekta.tokens.json'), 'utf8'));

// Runs the generator on a changed copy of the tokens and returns its exit status, error output and file.
function generate(change) {
	const dir = mkdtempSync(join(tmpdir(), 'generate-tokens-'));
	const tokens = structuredClone(original);
	change(tokens);
	writeFileSync(join(dir, 'rekta.tokens.json'), JSON.stringify(tokens));
	mkdirSync(join(dir, 'shell', 'Rekta'), { recursive: true });
	const run = spawnSync(process.execPath, [generator, dir, join(dir, 'shell')], { encoding: 'utf8' });
	const read = () => readFileSync(join(dir, 'shell', 'Rekta', 'Tokens.qml'), 'utf8');
	return { status: run.status, stderr: run.stderr, read };
}

function assertRefused(change, message) {
	const { status, stderr } = generate(change);
	assert.equal(status, 1);
	assert.match(stderr, message);
}

test('the unchanged tokens generate the module', () => {
	const { status, read } = generate(() => {});
	assert.equal(status, 0);
	assert.match(read(), /pragma Singleton/);
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
