'use strict';

const { test } = require( 'node:test' );
const assert = require( 'node:assert/strict' );
const G = require( '../../pages/mediawiki/Gadget-dimensions-geometry.js' );

const M4A_STOWED = { length: 3.32, width: 0.45, height: 0.8 };
const CUTLASS = { length: 37.5, width: 26.5, height: 11.5 };
const byId = ( id ) => G.CONTAINERS.concat( G.REFERENCES ).find( ( c ) => c.id === id );

test( 'fitCheck: rotates the box to its best orientation', () => {
	// Too long for the 8 SCU cube whichever way it turns
	assert.equal( G.fitCheck( M4A_STOWED, byId( 'scu-8' ) ).fits, false );
	// 2 × 1 × 1 lies along the 2 SCU container's length even when given upright
	assert.equal( G.fitCheck( { length: 1, width: 1, height: 2 }, byId( 'scu-2' ) ).fits, true );
} );

test( 'fitCheck: reports the largest overhang', () => {
	const check = G.fitCheck( M4A_STOWED, byId( 'scu-8' ) );
	assert.ok( Math.abs( check.over - 0.82 ) < 1e-9 );
} );

test( 'fitCheck: an exact fit fits', () => {
	assert.equal( G.fitCheck( { length: 1.25, width: 1.25, height: 1.25 }, byId( 'scu-1' ) ).fits, true );
} );

test( 'smallestFitting: the first container in size order that fits', () => {
	assert.equal( G.smallestFitting( M4A_STOWED ).id, 'scu-16' );
	assert.equal( G.smallestFitting( { length: 0.2, width: 0.2, height: 0.2 } ).id, 'scu-0.125' );
	assert.equal( G.smallestFitting( CUTLASS ), null );
} );

test( 'orientTo: longest side along the container\'s longest axis', () => {
	const oriented = G.orientTo( { length: 0.45, width: 0.8, height: 3.32 }, byId( 'scu-16' ) );
	assert.deepEqual( oriented, { length: 3.32, width: 0.45, height: 0.8 } );
} );

test( 'orientTo: equal container sides keep the input order of axes', () => {
	const oriented = G.orientTo( { length: 1, width: 2, height: 3 }, byId( 'scu-8' ) );
	assert.deepEqual( oriented, { length: 1, width: 2, height: 3 } );
} );

test( 'starterReference: the largest reference no longer than the object', () => {
	assert.equal( G.starterReference( CUTLASS ).id, 'human' );
	assert.equal( G.starterReference( { length: 1.8, width: 0.1, height: 0.1 } ).id, 'human' );
	assert.equal( G.starterReference( { length: 1, width: 0.2, height: 0.2 } ).id, 'banana' );
} );

test( 'starterReference: the smallest when the object is smaller than all', () => {
	assert.equal( G.starterReference( { length: 0.01, width: 0.01, height: 0.01 } ).id, 'banana' );
} );

test( 'addCompared: appends, but not twice and not past the limit', () => {
	assert.deepEqual( G.addCompared( [], 'human' ), [ 'human' ] );
	assert.deepEqual( G.addCompared( [ 'human' ], 'human' ), [ 'human' ] );
	const full = [ 'a', 'b', 'c' ];
	assert.equal( G.addCompared( full, 'd' ), full );
} );

test( 'VIEWS: Front looks from the near end of the row', () => {
	// Spin -90 brings the -x end, where the shortest objects stand, to the camera
	assert.deepEqual( G.VIEWS.front, { tilt: 90, spin: -90 } );
} );

test( 'boundsOf: the box around every item, from the ground up', () => {
	const bounds = G.boundsOf( [
		{ x: 0, y: -1, box: { length: 2, width: 2, height: 3 } },
		{ x: 3, y: -0.5, box: { length: 1, width: 1, height: 1 } }
	] );
	assert.deepEqual( bounds, { min: { x: 0, y: -1, z: 0 }, max: { x: 4, y: 1, z: 3 } } );
} );

test( 'layoutRow: boxes in a row, centred on the axis, with a gap', () => {
	const row = G.layoutRow( [ CUTLASS, byId( 'human' ) ] );
	const gap = 37.5 * 0.1;
	assert.equal( row.items[ 0 ].x, 0 );
	assert.equal( row.items[ 0 ].y, -13.25 );
	assert.equal( row.items[ 1 ].x, 37.5 + gap );
	assert.equal( row.items[ 1 ].y, -0.25 );
	assert.deepEqual( row.bounds, {
		min: { x: 0, y: -13.25, z: 0 },
		max: { x: 37.5 + gap + 0.3, y: 13.25, z: 11.5 }
	} );
} );

test( 'layoutFit: the oriented box shares the container\'s corner', () => {
	const fit = G.layoutFit( { length: 0.45, width: 0.8, height: 3.32 }, byId( 'scu-16' ) );
	assert.deepEqual( fit.items[ 0 ], { x: 0, y: -1.25, box: { length: 3.32, width: 0.45, height: 0.8 } } );
	assert.equal( fit.items[ 1 ].box.id, 'scu-16' );
	assert.deepEqual( fit.bounds, { min: { x: 0, y: -1.25, z: 0 }, max: { x: 5, y: 1.25, z: 2.5 } } );
} );

test( 'layoutFit: an oversized box widens the bounds', () => {
	// Its longest side, 3.32 m, takes the cube's last-ranked axis: height.
	const fit = G.layoutFit( M4A_STOWED, byId( 'scu-8' ) );
	assert.deepEqual( fit.bounds, { min: { x: 0, y: -1.25, z: 0 }, max: { x: 2.5, y: 1.25, z: 3.32 } } );
} );

test( 'gridStep and barStep: round lengths around a pixel target', () => {
	// 20 px per metre: a 1 m square is the first at least 18 px
	assert.equal( G.gridStep( 20, 18 ), 1 );
	// 20 px per metre: 5 m is the longest bar within 150 px
	assert.equal( G.barStep( 20, 150 ), 5 );
} );

test( 'formatLength and formatBox: up to three decimals, thousands separated', () => {
	assert.equal( G.formatLength( 2.994 ), '2.994 m' );
	assert.equal( G.formatLength( 1250 ), '1,250 m' );
	assert.equal( G.formatBox( { length: 37.5, width: 26.5, height: 11.5 } ), '37.5 × 26.5 × 11.5 m' );
} );
