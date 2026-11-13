/*
 * Gadget: Dimensions — the geometry behind the Compare size dialog: the
 * reference objects, the fit check, the scene layout and the view projection.
 * No DOM or mw access, so Node can test it.
 *
 * [[MediaWiki:Gadget-dimensionsDialog.js]]
 * [[MediaWiki:Gadget-dimensions-geometry.js]]
 *
 * A box is { length, width, height } in metres: length runs along the scene's
 * x axis, width along y, height up.
 */
( function () {
	'use strict';

	// Objects shown beside the page's own, which is always in the scene.
	const MAX_COMPARED = 3;

	// Standard cargo-container external sizes; the same table as
	// Module:Entity/Related's BOX_DIMENSIONS.
	const CONTAINERS = [
		{ id: 'scu-0.125', name: '1/8 SCU container', length: 0.5, width: 0.5, height: 0.5 },
		{ id: 'scu-1', name: '1 SCU container', length: 1.25, width: 1.25, height: 1.25 },
		{ id: 'scu-2', name: '2 SCU container', length: 2.5, width: 1.25, height: 1.25 },
		{ id: 'scu-4', name: '4 SCU container', length: 2.5, width: 2.5, height: 1.25 },
		{ id: 'scu-8', name: '8 SCU container', length: 2.5, width: 2.5, height: 2.5 },
		{ id: 'scu-16', name: '16 SCU container', length: 5, width: 2.5, height: 2.5 },
		{ id: 'scu-24', name: '24 SCU container', length: 7.5, width: 2.5, height: 2.5 },
		{ id: 'scu-32', name: '32 SCU container', length: 10, width: 2.5, height: 2.5 }
	];

	// Smallest first.
	const REFERENCES = [
		{ id: 'banana', name: 'Banana', length: 0.05, width: 0.05, height: 0.2 },
		{ id: 'human', name: 'Human', length: 0.3, width: 0.5, height: 1.8 }
	];

	// orbitCamera presets, degrees: tilt 0 looks straight down, 90 is level.
	// The row of objects runs along x, shortest first, so Front looks from the
	// near (-x) end: from the far end the tallest object would hide the rest.
	// iso and lvl views are the view cube's corners: the 3D angle from each
	// diagonal, from above and level.
	const VIEWS = {
		'3d': { tilt: 58, spin: -38 },
		top: { tilt: 0, spin: 0 },
		side: { tilt: 90, spin: 0 },
		side2: { tilt: 90, spin: 180 },
		front: { tilt: 90, spin: -90 },
		back: { tilt: 90, spin: 90 },
		iso2: { tilt: 58, spin: 38 },
		iso3: { tilt: 58, spin: 142 },
		iso4: { tilt: 58, spin: -142 },
		lvl1: { tilt: 90, spin: -38 },
		lvl2: { tilt: 90, spin: 38 },
		lvl3: { tilt: 90, spin: 142 },
		lvl4: { tilt: 90, spin: -142 }
	};

	const NICE_LENGTHS = [ 0.01, 0.02, 0.05, 0.1, 0.2, 0.25, 0.5, 1, 2, 5, 10, 20, 25, 50, 100, 200, 500 ];

	const EPSILON = 1e-9;

	/**
	 * @param {Object} box
	 * @return {number}
	 */
	function longestSide( box ) {
		return Math.max( box.length, box.width, box.height );
	}

	/**
	 * @param {Object} box
	 * @return {number[]} The three sides, shortest first
	 */
	function sortedSides( box ) {
		return [ box.length, box.width, box.height ].sort( ( a, b ) => a - b );
	}

	/**
	 * Whether a box fits a container in its best orientation. Pairing the
	 * sorted sides is optimal for axis-aligned boxes: any other pairing puts a
	 * longer side against a shorter one.
	 *
	 * @param {Object} box
	 * @param {Object} container
	 * @return {{fits: boolean, over: number}} over is the largest overhang in
	 *  metres, zero or negative when it fits
	 */
	function fitCheck( box, container ) {
		const a = sortedSides( box );
		const b = sortedSides( container );
		const over = Math.max( a[ 0 ] - b[ 0 ], a[ 1 ] - b[ 1 ], a[ 2 ] - b[ 2 ] );
		return { fits: over <= EPSILON, over };
	}

	/**
	 * @param {Object} box
	 * @param {Object[]} [containers] smallest first
	 * @return {Object|null} The smallest container the box fits
	 */
	function smallestFitting( box, containers ) {
		return ( containers || CONTAINERS ).find( ( c ) => fitCheck( box, c ).fits ) || null;
	}

	/**
	 * The box turned so its sides rank the same way as the container's: its
	 * longest side along the container's longest, and so on.
	 *
	 * @param {Object} box
	 * @param {Object} container
	 * @return {Object} box
	 */
	function orientTo( box, container ) {
		const sides = sortedSides( box );
		const axes = [ 'length', 'width', 'height' ]
			.map( ( axis, i ) => ( { axis, size: container[ axis ], i } ) )
			.sort( ( a, b ) => a.size - b.size || a.i - b.i );
		const out = {};
		axes.forEach( ( entry, rank ) => {
			out[ entry.axis ] = sides[ rank ];
		} );
		return out;
	}

	/**
	 * The reference the dialog starts with: the largest one no longer than the
	 * object, or the smallest when the object is smaller than all of them.
	 *
	 * @param {Object} box
	 * @param {Object[]} [references] smallest first
	 * @return {Object}
	 */
	function starterReference( box, references ) {
		const list = references || REFERENCES;
		const longest = longestSide( box );
		let pick = list[ 0 ];
		list.forEach( ( ref ) => {
			if ( longestSide( ref ) <= longest ) {
				pick = ref;
			}
		} );
		return pick;
	}

	/**
	 * @param {string[]} compared ids beside the page's object
	 * @param {string} id
	 * @param {number} [max]
	 * @return {string[]} compared with id appended, unchanged when full or present
	 */
	function addCompared( compared, id, max ) {
		if ( compared.indexOf( id ) !== -1 || compared.length >= ( max || MAX_COMPARED ) ) {
			return compared;
		}
		return compared.concat( [ id ] );
	}

	/**
	 * @param {Object[]} items layout items: x, y (the box's near corner) and box
	 * @return {{min: Object, max: Object}} Their bounding box in metres, x y z
	 */
	function boundsOf( items ) {
		const min = { x: Infinity, y: Infinity, z: 0 };
		const max = { x: -Infinity, y: -Infinity, z: 0 };
		items.forEach( ( item ) => {
			min.x = Math.min( min.x, item.x );
			min.y = Math.min( min.y, item.y );
			max.x = Math.max( max.x, item.x + item.box.length );
			max.y = Math.max( max.y, item.y + item.box.width );
			max.z = Math.max( max.z, item.box.height );
		} );
		return { min, max };
	}

	/**
	 * Boxes side by side along x, each centred on y = 0, sharing a ground plane.
	 *
	 * @param {Object[]} boxes
	 * @return {{items: Object[], bounds: Object}} items carry x and y (the
	 *  box's near corner) and box
	 */
	function layoutRow( boxes ) {
		const gap = Math.max.apply( null, boxes.map( longestSide ) ) * 0.1;
		const items = [];
		let x = 0;
		boxes.forEach( ( box ) => {
			items.push( { x, y: -box.width / 2, box } );
			x += box.length + gap;
		} );
		return { items, bounds: boundsOf( items ) };
	}

	/**
	 * The box, oriented to the container, sitting in the container's corner.
	 *
	 * @param {Object} box
	 * @param {Object} container
	 * @return {{items: Object[], bounds: Object}} the box first, then the container
	 */
	function layoutFit( box, container ) {
		const y = -container.width / 2;
		const items = [
			{ x: 0, y, box: orientTo( box, container ) },
			{ x: 0, y, box: container }
		];
		return { items, bounds: boundsOf( items ) };
	}

	/**
	 * @param {number} scale px per metre
	 * @param {number} minPx
	 * @return {number} The shortest round length drawn at least minPx long
	 */
	function gridStep( scale, minPx ) {
		return NICE_LENGTHS.find( ( n ) => n * scale >= minPx ) || NICE_LENGTHS[ NICE_LENGTHS.length - 1 ];
	}

	/**
	 * @param {number} scale px per metre
	 * @param {number} maxPx
	 * @return {number} The longest round length drawn at most maxPx long
	 */
	function barStep( scale, maxPx ) {
		const fitting = NICE_LENGTHS.filter( ( n ) => n * scale <= maxPx );
		return fitting.length ? fitting[ fitting.length - 1 ] : NICE_LENGTHS[ 0 ];
	}

	/**
	 * @param {number} metres
	 * @return {string} e.g. '37.5 m', '2.994 m', '1,250 m'
	 */
	function formatLength( metres ) {
		return metres.toLocaleString( 'en', { maximumFractionDigits: 3 } ) + ' m';
	}

	/**
	 * @param {Object} box
	 * @return {string} e.g. '37.5 × 26.5 × 11.5 m'
	 */
	function formatBox( box ) {
		const n = ( v ) => v.toLocaleString( 'en', { maximumFractionDigits: 3 } );
		return `${ n( box.length ) } × ${ n( box.width ) } × ${ n( box.height ) } m`;
	}

	module.exports = {
		MAX_COMPARED,
		CONTAINERS,
		REFERENCES,
		VIEWS,
		sortedSides,
		fitCheck,
		smallestFitting,
		orientTo,
		starterReference,
		addCompared,
		boundsOf,
		layoutRow,
		layoutFit,
		gridStep,
		barStep,
		formatLength,
		formatBox
	};
}() );
