'use strict';

const { test } = require( 'node:test' );
const assert = require( 'node:assert/strict' );
const M = require( '../../pages/mediawiki/Gadget-orbitCamera-math.js' );

const PRESETS = {
	iso: { tilt: 58, spin: -38 },
	top: { tilt: 0, spin: 0 },
	side: { tilt: 90, spin: 0 },
	front: { tilt: 90, spin: 90 }
};
const near = ( actual, expected ) => assert.ok( Math.abs( actual - expected ) < 1e-9, `${ actual } ≉ ${ expected }` );

test( 'clampTilt: between top-down and level', () => {
	assert.equal( M.clampTilt( -12 ), 0 );
	assert.equal( M.clampTilt( 45 ), 45 );
	assert.equal( M.clampTilt( 130 ), 90 );
} );

test( 'nearestTurn: the target spin closest to the current one', () => {
	assert.equal( M.nearestTurn( 322, -38 ), 322 );
	assert.equal( M.nearestTurn( 400, 0 ), 360 );
	assert.equal( M.nearestTurn( -100, 90 ), -270 );
} );

test( 'presetAt: a preset, whole turns included, or null', () => {
	assert.equal( M.presetAt( { tilt: 58, spin: -38 }, PRESETS ), 'iso' );
	assert.equal( M.presetAt( { tilt: 58, spin: 322 }, PRESETS ), 'iso' );
	assert.equal( M.presetAt( { tilt: 90, spin: -270 }, PRESETS ), 'front' );
	assert.equal( M.presetAt( { tilt: 40, spin: 12 }, PRESETS ), null );
} );

test( 'projectedSize: flat views read straight off the box', () => {
	const size = { x: 4, y: 2, z: 1 };
	const check = ( view, width, height ) => {
		const s = M.projectedSize( size, PRESETS[ view ] );
		near( s.width, width );
		near( s.height, height );
	};
	check( 'top', 4, 2 );
	check( 'side', 4, 1 );
	check( 'front', 2, 1 );
} );

test( 'projectedSize: a half turn gives the same silhouette', () => {
	const size = { x: 4, y: 2, z: 1 };
	const a = M.projectedSize( size, { tilt: 40, spin: 25 } );
	const b = M.projectedSize( size, { tilt: 40, spin: 205 } );
	near( a.width, b.width );
	near( a.height, b.height );
} );

test( 'fitScale: the tighter of the two viewport axes wins', () => {
	const viewport = { width: 800, height: 500 };
	const margin = { x: 0.8, y: 0.68 };
	near( M.fitScale( { x: 10, y: 1, z: 1 }, PRESETS.side, viewport, margin ), 800 * 0.8 / 10 );
	near( M.fitScale( { x: 1, y: 1, z: 10 }, PRESETS.side, viewport, margin ), 500 * 0.68 / 10 );
} );

test( 'orbit: right turns the near side right, down looks from above', () => {
	assert.deepEqual( M.orbit( { tilt: 58, spin: -38 }, 100, 0, 0.4 ), { tilt: 58, spin: -78 } );
	assert.deepEqual( M.orbit( { tilt: 58, spin: -38 }, 0, 50, 0.4 ), { tilt: 38, spin: -38 } );
	assert.equal( M.orbit( { tilt: 10, spin: 0 }, 0, 100, 0.4 ).tilt, 0 );
} );

test( 'zoomAbout: the point under the pointer stays put', () => {
	const camera = { scale: 10, x: 20, y: -5 };
	const point = { x: 100, y: 40 };
	const zoomed = M.zoomAbout( camera, 2, point, [ 1, 100 ] );
	assert.equal( zoomed.scale, 20 );
	// The scene point under `point`, in scene px at scale 1, is unchanged
	near( ( point.x - camera.x ) / camera.scale, ( point.x - zoomed.x ) / zoomed.scale );
	near( ( point.y - camera.y ) / camera.scale, ( point.y - zoomed.y ) / zoomed.scale );
} );

test( 'zoomAbout: clamped to the range, and a clamped zoom does not pan', () => {
	const camera = { scale: 10, x: 0, y: 0 };
	assert.deepEqual( M.zoomAbout( camera, 100, { x: 50, y: 50 }, [ 1, 10 ] ), { scale: 10, x: 0, y: 0 } );
	assert.equal( M.zoomAbout( camera, 0.01, { x: 0, y: 0 }, [ 2, 100 ] ).scale, 2 );
} );

test( 'pinch: spread scales, the midpoint carries the scene with it', () => {
	const start = { scale: 10, x: 0, y: 0, mid: { x: 30, y: 10 }, distance: 100 };
	const result = M.pinch( start, { x: 50, y: 10 }, 200, [ 1, 100 ] );
	assert.equal( result.scale, 20 );
	// The scene point under the starting midpoint is now under the new one
	near( ( start.mid.x - start.x ) / start.scale, ( 50 - result.x ) / result.scale );
	near( ( start.mid.y - start.y ) / start.scale, ( 10 - result.y ) / result.scale );
} );

test( 'wheelFactor: scrolling up zooms in, lines and pages count as pixels', () => {
	assert.ok( M.wheelFactor( -100, 0, false ) > 1 );
	assert.ok( M.wheelFactor( 100, 0, false ) < 1 );
	near( M.wheelFactor( 3, 1, false ), M.wheelFactor( 48, 0, false ) );
	// A trackpad pinch sends small deltas, so each counts for more
	assert.ok( M.wheelFactor( 10, 0, true ) < M.wheelFactor( 10, 0, false ) );
} );

test( 'transform: pan, zoom relative to the build scale, turn about the centre', () => {
	const t = M.transform( { tilt: 58, spin: -38, scale: 40, x: 12, y: -3 }, { x: 5, y: 0, z: 2 }, 20 );
	assert.equal( t, 'translate(12px, -3px) scale(2) rotateX(58deg) rotateZ(-38deg) translate3d(-100px, 0px, -40px)' );
} );
