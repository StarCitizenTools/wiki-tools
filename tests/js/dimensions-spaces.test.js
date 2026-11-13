'use strict';

const { test } = require( 'node:test' );
const assert = require( 'node:assert/strict' );
const S = require( '../../pages/mediawiki/Gadget-dimensions-spaces.js' );

const SHIPS = S.GROUPS.find( ( group ) => group.id === 'ships' );

const row = ( page, length, width, height, capacity, external, entityPage ) => ( {
	page_name: page,
	cargo_grid_length: length,
	cargo_grid_width: width,
	cargo_grid_height: height,
	cargo_grid_capacity: capacity,
	cargo_grid_external: external,
	'entity.page_name': entityPage === undefined ? page : entityPage
} );

test( 'groupQuery: joins each grid to its owner and filters on the subject type', () => {
	assert.equal(
		S.groupQuery( SHIPS ),
		'bucket(\'cargo_grid\').select(\'page_name\',\'cargo_grid_length\',\'cargo_grid_width\',\'cargo_grid_height\',' +
			'\'cargo_grid_capacity\',\'cargo_grid_external\',\'entity.page_name\')' +
			'.join(\'entity\',\'entity.page_name\',\'cargo_grid.page_name\')' +
			'.where(\'entity.subject_type\',\'Spacecraft\').limit(5000).run()'
	);
} );

test( 'requestParams: cacheable at the edge and in the browser, formatversion 2', () => {
	const params = S.requestParams( SHIPS );
	assert.equal( params.action, 'bucket' );
	assert.equal( params.formatversion, '2' );
	assert.equal( params.query, S.groupQuery( SHIPS ) );
	assert.equal( params.smaxage, '3600' );
	assert.equal( params.maxage, '300' );
	assert.equal( 'requestid' in params, false );
} );

test( 'requestParams: a retry carries its nonce as requestid', () => {
	assert.equal( S.requestParams( SHIPS, '1700000000000' ).requestid, '1700000000000' );
} );

test( 'ownersFromRows: one owner per page, its grids in row order, owners by name', () => {
	const owners = S.ownersFromRows( [
		row( 'Freelancer', 11.25, 2.5, 3.75, 54, false ),
		row( 'Cutlass Black', 6.25, 5, 2.5, 40, false ),
		row( 'Freelancer', 1.25, 2.5, 3.75, 6, false )
	], SHIPS );
	assert.deepEqual( owners.map( ( owner ) => owner.name ), [ 'Cutlass Black', 'Freelancer' ] );
	assert.equal( owners[ 1 ].kind, 'Ship' );
	assert.deepEqual( owners[ 1 ].spaces.map( ( space ) => space.capacity ), [ 54, 6 ] );
} );

test( 'ownersFromRows: names sort numerically', () => {
	const owners = S.ownersFromRows( [ row( '890 Jump', 15, 7.5, 5, 288 ), row( '100i', 2.5, 1.25, 1.25, 2 ) ], SHIPS );
	assert.deepEqual( owners.map( ( owner ) => owner.name ), [ '100i', '890 Jump' ] );
} );

test( 'ownersFromRows: drops a row joined to a page differing only in case', () => {
	const owners = S.ownersFromRows( [ row( 'Lightfire', 2.5, 1.25, 1.25, 2, false, 'LightFire' ) ], SHIPS );
	assert.deepEqual( owners, [] );
} );

test( 'ownersFromRows: drops a grid without a full size; a missing flag is not external', () => {
	const owners = S.ownersFromRows( [
		row( 'Nomad', 5, 3.75, 2.5, 24, undefined ),
		row( 'Nomad', 5, null, 2.5, 24, false )
	], SHIPS );
	assert.equal( owners[ 0 ].spaces.length, 1 );
	assert.equal( owners[ 0 ].spaces[ 0 ].external, false );
} );

test( 'groupSpaces: identical grids collapse with a count, smallest first', () => {
	const grid = ( length, width, height, capacity, external ) => ( { length, width, height, capacity, external } );
	const groups = S.groupSpaces( [
		grid( 7.5, 5, 5, 96, true ),
		grid( 1.25, 5, 2.5, 8, true ),
		grid( 7.5, 5, 5, 96, true ),
		grid( 7.5, 5, 5, 96, false )
	] );
	assert.deepEqual( groups.map( ( entry ) => [ entry.space.capacity, entry.count, entry.space.external ] ), [
		[ 8, 1, true ],
		[ 96, 2, true ],
		[ 96, 1, false ]
	] );
} );

test( 'totalCapacity: sums SCU', () => {
	assert.equal( S.totalCapacity( [ { capacity: 54 }, { capacity: 6 }, { capacity: 6 } ] ), 66 );
} );

test( 'search: names starting with the query first, then by name, ignoring case', () => {
	const names = [ 'MISC Freelancer', 'Freelancer MAX', 'Freelancer', 'Cutlass Black' ].map( ( name ) => ( { name } ) );
	assert.deepEqual( S.search( names, ' FREE' ).map( ( entry ) => entry.name ), [ 'Freelancer', 'Freelancer MAX', 'MISC Freelancer' ] );
} );

test( 'search: a blank query matches nothing', () => {
	assert.deepEqual( S.search( [ { name: 'Freelancer' } ], '  ' ), [] );
} );
