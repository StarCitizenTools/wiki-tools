/*
 * Gadget: orbitCamera — the camera maths: orbiting, fitting, zooming about a
 * point and pinching. No DOM or mw access, so Node can test it.
 *
 * [[MediaWiki:Gadget-orbitCamera.js]]
 * [[MediaWiki:Gadget-orbitCamera-math.js]]
 *
 * A camera is { tilt, spin, scale, x, y }: tilt and spin in degrees (tilt 0
 * looks straight down, 90 is level with the ground), scale in pixels per
 * scene unit, and x and y the pan in pixels from the viewport centre. Content
 * is a box of size { x, y, z } scene units around a centre point; z is up.
 */
( function () {
	'use strict';

	const clamp = ( value, min, max ) => Math.min( max, Math.max( min, value ) );

	/**
	 * @param {number} tilt degrees
	 * @return {number} tilt held between top-down (0) and level (90), so the
	 *  camera never looks up at the underside of the content
	 */
	function clampTilt( tilt ) {
		return clamp( tilt, 0, 90 );
	}

	/**
	 * The spin equal to target, modulo a full turn, that lies closest to
	 * current: a transition to it then takes the short way round.
	 *
	 * @param {number} current degrees
	 * @param {number} target degrees
	 * @return {number}
	 */
	function nearestTurn( current, target ) {
		return target + 360 * Math.round( ( current - target ) / 360 );
	}

	/**
	 * @param {{tilt: number, spin: number}} angles
	 * @param {Object} presets named { tilt, spin } views
	 * @return {string|null} The preset the camera is at, whole turns included
	 */
	function presetAt( angles, presets ) {
		const apart = ( a, b ) => Math.abs( ( ( ( a - b ) % 360 ) + 540 ) % 360 - 180 );
		return Object.keys( presets ).find( ( key ) => apart( presets[ key ].tilt, angles.tilt ) < 0.5 &&
			apart( presets[ key ].spin, angles.spin ) < 0.5 ) || null;
	}

	/**
	 * Width and height of the content's silhouette on screen, in scene units.
	 *
	 * @param {{x: number, y: number, z: number}} size
	 * @param {{tilt: number, spin: number}} angles
	 * @return {{width: number, height: number}}
	 */
	function projectedSize( size, angles ) {
		const tilt = angles.tilt * Math.PI / 180;
		const spin = angles.spin * Math.PI / 180;
		const cos = Math.abs( Math.cos( spin ) );
		const sin = Math.abs( Math.sin( spin ) );
		return {
			width: size.x * cos + size.y * sin,
			height: ( size.x * sin + size.y * cos ) * Math.cos( tilt ) + size.z * Math.sin( tilt )
		};
	}

	/**
	 * @param {{x: number, y: number, z: number}} size
	 * @param {{tilt: number, spin: number}} angles
	 * @param {{width: number, height: number}} viewport px
	 * @param {{x: number, y: number}} margin share of the viewport to fill
	 * @return {number} The scale, px per unit, that fits the content
	 */
	function fitScale( size, angles, viewport, margin ) {
		const silhouette = projectedSize( size, angles );
		return Math.min(
			viewport.width * margin.x / silhouette.width,
			viewport.height * margin.y / silhouette.height
		);
	}

	/**
	 * @param {{tilt: number, spin: number}} start angles when the drag began
	 * @param {number} dx px dragged right
	 * @param {number} dy px dragged down
	 * @param {number} rate degrees per px
	 * @return {{tilt: number, spin: number}} Dragging right turns the near side
	 *  right; dragging down looks more from above
	 */
	function orbit( start, dx, dy, rate ) {
		return { tilt: clampTilt( start.tilt - dy * rate ), spin: start.spin - dx * rate };
	}

	/**
	 * Zoom while the scene point under `point` stays under it.
	 *
	 * @param {{scale: number, x: number, y: number}} camera
	 * @param {number} factor
	 * @param {{x: number, y: number}} point px from the viewport centre
	 * @param {number[]} range [ min, max ] scale
	 * @return {{scale: number, x: number, y: number}}
	 */
	function zoomAbout( camera, factor, point, range ) {
		const scale = clamp( camera.scale * factor, range[ 0 ], range[ 1 ] );
		const k = scale / camera.scale;
		return {
			scale,
			x: point.x - ( point.x - camera.x ) * k,
			y: point.y - ( point.y - camera.y ) * k
		};
	}

	/**
	 * Two-finger zoom and pan: the scene point that was under the fingers'
	 * starting midpoint follows their midpoint, and the scale follows their
	 * spread.
	 *
	 * @param {Object} start scale, x and y of the camera, mid (px from the
	 *  viewport centre) and distance (px) of the fingers when the pinch began
	 * @param {{x: number, y: number}} mid
	 * @param {number} distance
	 * @param {number[]} range [ min, max ] scale
	 * @return {{scale: number, x: number, y: number}}
	 */
	function pinch( start, mid, distance, range ) {
		const scale = clamp( start.scale * distance / start.distance, range[ 0 ], range[ 1 ] );
		const k = scale / start.scale;
		return {
			scale,
			x: mid.x - ( start.mid.x - start.x ) * k,
			y: mid.y - ( start.mid.y - start.y ) * k
		};
	}

	/**
	 * @param {number} deltaY WheelEvent.deltaY
	 * @param {number} deltaMode WheelEvent.deltaMode: pixels, lines or pages
	 * @param {boolean} pinching a trackpad pinch, which browsers send as a
	 *  wheel with ctrlKey and much smaller deltas
	 * @return {number} Zoom factor; one mouse-wheel notch is about 1.2×
	 */
	function wheelFactor( deltaY, deltaMode, pinching ) {
		const px = deltaY * ( deltaMode === 1 ? 16 : deltaMode === 2 ? 400 : 1 );
		return Math.exp( -px * ( pinching ? 0.01 : 0.002 ) );
	}

	/**
	 * @param {Object} camera
	 * @param {{x: number, y: number, z: number}} center scene units
	 * @param {number} buildScale px per unit the content was built at
	 * @return {string} The scene's CSS transform: pan, zoom, then the turn
	 *  about the content's centre. Always the same function list, so CSS can
	 *  interpolate between any two.
	 */
	function transform( camera, center, buildScale ) {
		return `translate(${ camera.x }px, ${ camera.y }px) scale(${ camera.scale / buildScale }) ` +
			`rotateX(${ camera.tilt }deg) rotateZ(${ camera.spin }deg) ` +
			`translate3d(${ -center.x * buildScale }px, ${ -center.y * buildScale }px, ${ -center.z * buildScale }px)`;
	}

	module.exports = {
		clampTilt,
		nearestTurn,
		presetAt,
		projectedSize,
		fitScale,
		orbit,
		zoomAbout,
		pinch,
		wheelFactor,
		transform
	};
}() );
