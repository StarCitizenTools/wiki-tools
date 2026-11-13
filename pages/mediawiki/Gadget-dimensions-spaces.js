/*
 * Gadget: Dimensions — the cargo spaces Fit tests against besides the
 * standard containers: the groups the picker lists, the Bucket query each one
 * loads with, and the search across them. No DOM or mw access, so Node can
 * test it.
 *
 * [[MediaWiki:Gadget-dimensionsDialog.js]]
 * [[MediaWiki:Gadget-dimensions-spaces.js]]
 *
 * An owner is a page holding one or more spaces, { name, kind, spaces }, and a
 * space is a box in metres plus its capacity in SCU, whether it is on the
 * outside of the hull, and the item limits within which the grid secures what
 * it holds: { length, width, height, capacity, external, limits }.
 */
( function () {
	'use strict';

	// Each group lists the owners whose Module:Entity subject type it names, so
	// another kind of page that writes cargo_grid rows joins with one line here.
	// Grav-lev vehicles are left out while none of them has a grid.
	const GROUPS = [
		{ id: 'ships', label: 'Ships', kind: 'Ship', subjectType: 'Spacecraft' },
		{ id: 'ground', label: 'Ground vehicles', kind: 'Ground vehicle', subjectType: 'Ground vehicle' }
	];

	// Each limit's sides, shortest first, as Module:Entity/Vehicle stores them.
	const LIMIT_FIELDS = {
		min: [ 'cargo_grid_minimum_item_shortest_side', 'cargo_grid_minimum_item_middle_side', 'cargo_grid_minimum_item_longest_side' ],
		max: [ 'cargo_grid_maximum_item_shortest_side', 'cargo_grid_maximum_item_middle_side', 'cargo_grid_maximum_item_longest_side' ]
	};

	const FIELDS = [
		'cargo_grid_length',
		'cargo_grid_width',
		'cargo_grid_height',
		'cargo_grid_capacity',
		'cargo_grid_external'
	].concat( LIMIT_FIELDS.min, LIMIT_FIELDS.max );

	/**
	 * @param {string} a
	 * @param {string} b
	 * @return {number}
	 */
	function compareNames( a, b ) {
		return a.localeCompare( b, 'en', { numeric: true, sensitivity: 'base' } );
	}

	/**
	 * The Bucket query, in Bucket's Lua syntax, for every cargo grid of a
	 * group's owners. The owner's own entity page_name comes back too, for
	 * ownersFromRows' case check.
	 *
	 * @param {Object} group an entry of GROUPS
	 * @return {string}
	 */
	function groupQuery( group ) {
		const select = [ 'page_name' ].concat( FIELDS, [ 'entity.page_name' ] )
			.map( ( field ) => `'${ field }'` )
			.join( ',' );
		return `bucket('cargo_grid').select(${ select })` +
			'.join(\'entity\',\'entity.page_name\',\'cargo_grid.page_name\')' +
			`.where('entity.subject_type','${ group.subjectType }')` +
			'.limit(5000).run()';
	}

	/**
	 * The api.php parameters for a group's request. Bucket's API module allows
	 * public caching, so Cloudflare keeps the answer for an hour and browsers
	 * for five minutes: grids change only when vehicle pages re-parse. Bucket
	 * answers a failed query with a cacheable 200 too, so a retry passes a
	 * nonce as requestid, which the API echoes without a warning, to ask past
	 * the cached copy.
	 *
	 * @param {Object} group an entry of GROUPS
	 * @param {string} [nonce] set on a retry
	 * @return {Object<string, string>}
	 */
	function requestParams( group, nonce ) {
		const params = {
			action: 'bucket',
			format: 'json',
			// formatversion 1 sends a true BOOLEAN as "" and leaves a false one out.
			formatversion: '2',
			query: groupQuery( group ),
			maxage: '300',
			smaxage: '3600'
		};
		if ( nonce ) {
			params.requestid = nonce;
		}
		return params;
	}

	/**
	 * A grid's item limits from its row. A maximum of all zeros is no maximum,
	 * and a minimum of zeros no minimum.
	 *
	 * @param {Object} row
	 * @return {Object|null} { min, max }, each three sides shortest first or
	 *  null; null when the row has neither, as before its vehicle page
	 *  re-parsed with them
	 */
	function limitsFromRow( row ) {
		const sides = ( fields ) => {
			const values = fields.map( ( field ) => ( row[ field ] === null || row[ field ] === undefined || row[ field ] === '' ? NaN : Number( row[ field ] ) ) );
			return values.every( ( value ) => isFinite( value ) ) ? values : null;
		};
		const min = sides( LIMIT_FIELDS.min );
		let max = sides( LIMIT_FIELDS.max );
		if ( max && !max.some( ( side ) => side > 0 ) ) {
			max = null;
		}
		return min || max ? { min, max } : null;
	}

	/**
	 * Owners from a group query's rows, by name. Bucket matches the join key
	 * without regard to case, so a row joined to an entity page whose name
	 * differs in case belongs to another page and is dropped.
	 *
	 * @param {Object[]} rows the API's formatversion=2 rows
	 * @param {Object} group an entry of GROUPS
	 * @return {Object[]} owners
	 */
	function ownersFromRows( rows, group ) {
		const byName = {};
		const owners = [];
		rows.forEach( ( row ) => {
			if ( row[ 'entity.page_name' ] !== row.page_name ) {
				return;
			}
			const space = {
				length: Number( row.cargo_grid_length ),
				width: Number( row.cargo_grid_width ),
				height: Number( row.cargo_grid_height ),
				capacity: Number( row.cargo_grid_capacity ) || 0,
				external: row.cargo_grid_external === true,
				limits: limitsFromRow( row )
			};
			if ( !( space.length > 0 && space.width > 0 && space.height > 0 ) ) {
				return;
			}
			if ( !byName[ row.page_name ] ) {
				byName[ row.page_name ] = { name: row.page_name, kind: group.kind, spaces: [] };
				owners.push( byName[ row.page_name ] );
			}
			byName[ row.page_name ].spaces.push( space );
		} );
		return owners.sort( ( a, b ) => compareNames( a.name, b.name ) );
	}

	/**
	 * A ship often carries the same grid more than once (the Caterpillar's
	 * modules), so identical spaces collapse into one entry with a count.
	 *
	 * @param {Object[]} spaces
	 * @return {Object[]} { key, count, space }, smallest capacity first
	 */
	function groupSpaces( spaces ) {
		const out = [];
		spaces.forEach( ( space ) => {
			const key = [ space.length, space.width, space.height, space.external ? 'e' : 'i', JSON.stringify( space.limits ) ].join( '-' );
			const hit = out.find( ( entry ) => entry.key === key );
			if ( hit ) {
				hit.count += 1;
			} else {
				out.push( { key, count: 1, space } );
			}
		} );
		return out.sort( ( a, b ) => a.space.capacity - b.space.capacity || a.space.length - b.space.length );
	}

	/**
	 * @param {Object[]} spaces
	 * @return {number} SCU
	 */
	function totalCapacity( spaces ) {
		return spaces.reduce( ( sum, space ) => sum + space.capacity, 0 );
	}

	/**
	 * Entries whose name holds the query, ignoring case: names that start
	 * with it first, then by name.
	 *
	 * @param {Object[]} entries anything with a name
	 * @param {string} query
	 * @return {Object[]} empty for a blank query
	 */
	function search( entries, query ) {
		const q = query.trim().toLowerCase();
		if ( !q ) {
			return [];
		}
		const rank = ( entry ) => ( entry.name.toLowerCase().indexOf( q ) === 0 ? 0 : 1 );
		return entries
			.filter( ( entry ) => entry.name.toLowerCase().indexOf( q ) !== -1 )
			.sort( ( a, b ) => rank( a ) - rank( b ) || compareNames( a.name, b.name ) );
	}

	module.exports = {
		GROUPS,
		groupQuery,
		requestParams,
		ownersFromRows,
		groupSpaces,
		totalCapacity,
		search
	};
}() );
