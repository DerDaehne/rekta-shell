#!/usr/bin/env node
// Writes shell/Rekta/Tokens.qml and shell/Rekta/IconData.js from Rekta Design's dist (rekta.tokens.json, rekta.icons.json).
//   node scripts/generate-tokens.mjs <rekta-design dist dir> <shell dir>          write the files
//   node scripts/generate-tokens.mjs <rekta-design dist dir> <shell dir> --check  fail if one differs
// Every value comes from Rekta Design; the only product choice is the typeface.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const FONT_SANS = 'Atkinson Hyperlegible Next';
// The tokens list CSS font stacks; on Linux the fontconfig generic picks the monospace face.
const FONT_MONO = 'monospace';

// Documentation, not values: descriptions, and the hooks (runtime custom properties of the web stylesheet).
const SKIPPED_GROUPS = new Set(['name', 'version', 'units', 'descriptions', 'hooks']);

// QML reads a property named on<Capital> as a signal handler, so such tokens need another QML name.
const QML_NAMES = { 'on-accent': 'textOnAccent' };

function camel(name) {
	const qmlName = QML_NAMES[name] ?? name.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
	if (/^on[A-Z_]/.test(qmlName)) throw new Error(`${name}: QML would read ${qmlName} as a signal handler; add it to QML_NAMES`);
	return qmlName;
}

// Rekta writes translucent colours as #rrggbbaa; Qt reads eight hex digits as #aarrggbb.
function qtColour(hex) {
	if (!/^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(hex)) throw new Error(`not a colour: ${hex}`);
	return hex.length === 9 ? `#${hex.slice(7)}${hex.slice(1, 7)}` : hex;
}

// A CSS cubic-bezier [x1, y1, x2, y2] as a Qt bezierCurve, which ends with its end point (1, 1).
function qtBezier(curve) {
	if (!Array.isArray(curve) || curve.length !== 4 || !curve.every(Number.isFinite)) {
		throw new Error(`not a cubic-bezier: ${JSON.stringify(curve)}`);
	}
	return `[${[...curve, 1, 1].join(', ')}]`;
}

function number(value, name) {
	if (!Number.isFinite(value)) throw new Error(`${name}: expected a number, got ${JSON.stringify(value)}`);
	return String(value);
}

function isFluid(value) {
	return value !== null && typeof value === 'object' && ['min', 'max', 'viewport'].every((k) => Number.isFinite(value[k]));
}

const property = (type, name, value) => `    readonly property ${type} ${camel(name)}: ${value}`;

// One typed component per kind of mode, so tools and readers know the members of Tokens.color and friends.
function modeComponent(type, qmlType, modes) {
	const [first, ...others] = Object.values(modes);
	const names = Object.keys(first);
	for (const other of others) {
		if (Object.keys(other).join() !== names.join()) throw new Error(`${type}: the modes do not share the same tokens`);
	}
	return [`    component ${type}: QtObject {`, ...names.map((name) => `        required property ${qmlType} ${camel(name)}`), '    }'];
}

function modeInstance(type, mode, values, format) {
	const lines = Object.entries(values).map(([name, value]) => `        ${camel(name)}: ${format(value, name)}`);
	return [`    readonly property ${type} ${mode}: ${type} {`, ...lines, '    }'];
}

function typography(entries) {
	return Object.entries(entries).map(([name, value]) => {
		if (name === 'font-sans') return property('string', name, JSON.stringify(FONT_SANS));
		if (name === 'font-mono') return property('string', name, JSON.stringify(FONT_MONO));
		if (name.startsWith('font-weight-')) return property('int', name, number(value, name));
		if (name.startsWith('line-height-')) return property('real', name, number(value, name));
		if (name.startsWith('font-size-') && isFluid(value)) {
			return property('var', name, `({ min: ${value.min}, max: ${value.max}, viewport: ${value.viewport} })`);
		}
		if (name.startsWith('font-size-')) return property('real', name, number(value, name));
		throw new Error(`typography: no mapping for ${name}`);
	});
}

function motion(entries) {
	return Object.entries(entries).map(([name, value]) => {
		if (name.startsWith('duration-')) return property('int', name, `reducedMotion ? 0 : ${number(value, name)}`);
		if (name.startsWith('ease-')) return property('var', name, qtBezier(value));
		return property('real', name, number(value, name));
	});
}

function numbers(group, entries) {
	return Object.entries(entries).map(([name, value]) => property('real', name, number(value, `${group}.${name}`)));
}

// The bindings below switch between exactly these modes; a new mode needs a new binding.
function expectModes(group, modes, names) {
	const actual = Object.keys(modes).sort().join(', ');
	if (actual !== [...names].sort().join(', ')) throw new Error(`${group}: expected ${names.join(', ')}, got ${actual}`);
}

const KNOWN_GROUPS = ['themes', 'densities', 'typography', 'spacing', 'radius', 'size', 'motion', 'timing', 'layer', 'breakpoint'];

function expectKnownGroups(tokens) {
	const unknown = Object.keys(tokens).filter((g) => !SKIPPED_GROUPS.has(g) && !KNOWN_GROUPS.includes(g));
	if (unknown.length) throw new Error(`no mapping for token group(s): ${unknown.join(', ')}`);
	expectModes('themes', tokens.themes, ['light', 'dark']);
	expectModes('densities', tokens.densities, ['comfortable', 'compact']);
}

function inputs(tokens) {
	return [
		`// Generated by scripts/generate-tokens.mjs from ${tokens.name} ${tokens.version}. Do not edit.`,
		'pragma Singleton',
		'import QtQuick',
		'',
		'QtObject {',
		'    // Inputs: set from the preferences (theme, density, reduced motion).',
		'    property string theme: "light"',
		'    property string density: "compact"',
		'    property bool reducedMotion: false',
	];
}

function modes(tokens) {
	const densityKeys = Object.keys(tokens.densities.compact);
	return [
		...modeComponent('Colours', 'color', tokens.themes),
		...Object.entries(tokens.themes).flatMap(([theme, colours]) => modeInstance('Colours', theme, colours, (hex) => `"${qtColour(hex)}"`)),
		'    readonly property Colours color: theme === "dark" ? dark : light',
		'',
		...modeComponent('Density', 'int', tokens.densities),
		...Object.entries(tokens.densities).flatMap(([density, values]) => modeInstance('Density', density, values, number)),
		'    readonly property Density currentDensity: density === "comfortable" ? comfortable : compact',
		...densityKeys.map((name) => property('int', name, `currentDensity.${camel(name)}`)),
	];
}

function scalars(tokens) {
	return [
		...typography(tokens.typography),
		'',
		...numbers('spacing', tokens.spacing),
		...numbers('radius', tokens.radius),
		...numbers('size', tokens.size),
		'',
		...motion(tokens.motion),
		...Object.entries(tokens.timing).map(([name, v]) => property('int', name, number(v, `timing.${name}`))),
		'',
		...numbers('layer', tokens.layer),
		...numbers('breakpoint', tokens.breakpoint),
	];
}

function helpers(tokens) {
	const motionDurations = Object.keys(tokens.motion).filter((n) => n.startsWith('duration-')).map(camel);
	const timingDurations = Object.keys(tokens.timing).map(camel);
	return [
		`    readonly property var motionDurations: ${JSON.stringify(motionDurations)}`,
		`    readonly property var timingDurations: ${JSON.stringify(timingDurations)}`,
		'',
		'    // A fluid size {min, max, viewport} at the width of the box that hosts the text; a plain number stays.',
		'    function fluid(size, width) {',
		'        if (typeof size === "number")',
		'            return size;',
		'        return Math.min(size.max, Math.max(size.min, size.viewport * width));',
		'    }',
		'}',
	];
}

function render(tokens) {
	expectKnownGroups(tokens);
	return [...inputs(tokens), '', ...modes(tokens), '', ...scalars(tokens), '', ...helpers(tokens), ''].join('\n');
}

// Two tokens must never land on one QML name (e.g. a motion and a timing duration).
function expectUniqueNames(qml) {
	const names = [...qml.matchAll(/^    (?:readonly )?property \S+ (\w+):/gm)].map((m) => m[1]);
	const twice = names.filter((n, i) => names.indexOf(n) !== i);
	if (twice.length) throw new Error(`tokens collide on: ${[...new Set(twice)].join(', ')}`);
	return qml;
}

// A circle as two SVG arcs, so every icon shape is path data for QML's PathSvg.
function circlePath({ cx, cy, r }) {
	const [x, y, radius] = [cx, cy, r].map(Number);
	if (![x, y, radius].every(Number.isFinite)) throw new Error(`not a circle: ${JSON.stringify({ cx, cy, r })}`);
	return `M${x - radius} ${y}a${radius} ${radius} 0 1 0 ${2 * radius} 0a${radius} ${radius} 0 1 0 ${-2 * radius} 0z`;
}

const NUMBER = String.raw`-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?`;
const LEADING_RELATIVE_MOVE = new RegExp(`^\\s*m\\s*(${NUMBER})[\\s,]*(${NUMBER})`);

// SVG reads a path's leading relative moveto as absolute, with its further pairs as relative linetos. Joined after
// another shape it would move relative to that shape, so it is written out absolute.
function absoluteStart(d) {
	const match = LEADING_RELATIVE_MOVE.exec(d);
	if (!match) return d;
	const rest = d.slice(match[0].length);
	const impliedLines = /^[\s,]*[-.\d]/.test(rest);
	return `M${match[1]} ${match[2]}${impliedLines ? ' l' : ''}${rest}`;
}

function shapePath({ tag, attrs }) {
	if (tag === 'path') return absoluteStart(attrs.d);
	if (tag === 'circle') return circlePath(attrs);
	throw new Error(`no mapping for icon shape <${tag}>`);
}

const isSolid = ({ attrs }) => attrs.fill !== undefined && attrs.fill !== 'none';

// The attributes each shape may carry; anything else (a transform, its own stroke width) would vanish silently.
const SHAPE_ATTRIBUTES = { path: ['d', 'fill', 'stroke'], circle: ['cx', 'cy', 'r', 'fill', 'stroke'] };
// The caps and joins Icon.qml knows how to draw.
const LINE_CAPS = ['butt', 'square', 'round'];
const LINE_JOINS = ['miter', 'bevel', 'round'];

function expectKnownShapes(icon, shapes) {
	for (const { tag, attrs } of shapes) {
		if (!SHAPE_ATTRIBUTES[tag]) throw new Error(`no mapping for icon shape <${tag}>`);
		const unknown = Object.keys(attrs).filter((name) => !SHAPE_ATTRIBUTES[tag].includes(name));
		if (unknown.length) throw new Error(`${icon}: no mapping for <${tag}> attribute(s) ${unknown.join(', ')}`);
	}
}

function expectKnownLines(set) {
	if (!LINE_CAPS.includes(set.lineCap)) throw new Error(`no mapping for line cap ${set.lineCap}`);
	if (!LINE_JOINS.includes(set.lineJoin)) throw new Error(`no mapping for line join ${set.lineJoin}`);
}

// Every icon as two path strings: its outlines (stroked) and its solid shapes (filled).
function renderIcons(set) {
	expectKnownLines(set);
	const entries = Object.entries(set.icons).map(([name, shapes]) => {
		expectKnownShapes(name, shapes);
		const stroke = shapes.filter((s) => !isSolid(s)).map(shapePath).join(' ');
		const fill = shapes.filter(isSolid).map(shapePath).join(' ');
		return `    ${JSON.stringify(name)}: { stroke: ${JSON.stringify(stroke)}, fill: ${JSON.stringify(fill)} }`;
	});
	return [
		`// Generated by scripts/generate-tokens.mjs from ${set.name} ${set.version}. Do not edit.`,
		'.pragma library',
		'',
		`var grid = ${set.grid};`,
		`var strokeWidth = ${set.strokeWidth};`,
		`var lineCap = ${JSON.stringify(set.lineCap)};`,
		`var lineJoin = ${JSON.stringify(set.lineJoin)};`,
		'var icons = {',
		entries.join(',\n'),
		'};',
		'',
	].join('\n');
}

// Every generated file with its content, rendered from the dist; throws on anything it cannot map.
function renderAll(distDir) {
	const read = (name) => JSON.parse(readFileSync(join(distDir, name), 'utf8'));
	const tokens = read('rekta.tokens.json');
	return {
		source: `${tokens.name} ${tokens.version}`,
		files: { 'Tokens.qml': expectUniqueNames(render(tokens)), 'IconData.js': renderIcons(read('rekta.icons.json')) },
	};
}

function main([distDir, shellDir, flag]) {
	if (!distDir || !shellDir || (flag && flag !== '--check')) {
		console.error('usage: generate-tokens.mjs <rekta-design dist dir> <shell dir> [--check]');
		return 2;
	}
	let generated;
	try {
		generated = renderAll(distDir);
	} catch (error) {
		console.error(`generate-tokens: ${error.message}. Map the new tokens in scripts/generate-tokens.mjs.`);
		return 1;
	}
	const target = (name) => join(shellDir, 'Rekta', name);
	if (flag !== '--check') {
		for (const [name, content] of Object.entries(generated.files)) writeFileSync(target(name), content);
		return 0;
	}
	const drifted = Object.entries(generated.files).filter(([name, content]) => readOrEmpty(target(name)) !== content);
	for (const [name] of drifted) {
		console.error(`${target(name)} differs from ${generated.source}. Regenerate it with: nix run .#tokens`);
	}
	return drifted.length ? 1 : 0;
}

// A missing file reads as empty, which is drift too.
function readOrEmpty(path) {
	try {
		return readFileSync(path, 'utf8');
	} catch {
		return '';
	}
}

process.exitCode = main(process.argv.slice(2));
