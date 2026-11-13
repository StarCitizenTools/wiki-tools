/*
 * Gadget: orbitCamera — orbit, zoom and pan for a CSS 3D scene. Drag to
 * orbit; wheel or pinch to zoom about the pointer; right-drag, Shift-drag or
 * two fingers to pan. A library for other gadgets, with no interface of its
 * own: `require( 'ext.gadget.orbitCamera' )`.
 *
 * [[MediaWiki:Gadget-orbitCamera.js]]
 * [[MediaWiki:Gadget-orbitCamera-math.js]]
 *
 * The consumer builds its scene at some pixels per unit (buildScale), places
 * it at the viewport's centre, and tells the camera the content's size and
 * centre in units. The camera then moves the scene with one transform and
 * never rebuilds it. Turning never changes the zoom; fitting happens only on
 * fit(), setPreset() and setContent( …, { fit: true } ). onSettle fires once
 * a gesture or animation ends: the moment to rebuild the content at the
 * current scale, since CSS scale also scales borders and backgrounds.
 */
( function () {
	'use strict';

	const math = require( './orbitCamera-math.js' );

	const ORBIT_RATE = 0.4;
	const EASE = 'cubic-bezier(0.2, 0.7, 0.2, 1)';
	const ANIMATION_MS = 450;
	const WHEEL_SETTLE_MS = 150;

	class OrbitCamera {
		/**
		 * @param {HTMLElement} viewport takes the gestures; positioned, with the
		 *  scene at its centre
		 * @param {HTMLElement} scene the element the camera transforms
		 * @param {Object} options
		 * @param {Object} options.presets named { tilt, spin } views
		 * @param {string} options.initial the preset to start at
		 * @param {{x: number, y: number}} [options.margin] share of the viewport
		 *  that fitted content fills
		 * @param {number[]} [options.zoomRange] [ min, max ] as multiples of the
		 *  fitted scale
		 * @param {Function} [options.onChange] called with the state after every move
		 * @param {Function} [options.onSettle] called with the state once still
		 */
		constructor( viewport, scene, options ) {
			this.viewport = viewport;
			this.scene = scene;
			this.presets = options.presets;
			this.margin = options.margin || { x: 0.8, y: 0.8 };
			this.zoomRange = options.zoomRange || [ 0.25, 50 ];
			this.onChange = options.onChange || ( () => {} );
			this.onSettle = options.onSettle || ( () => {} );
			this.camera = Object.assign( { scale: 1, x: 0, y: 0 }, this.presets[ options.initial ] );
			this.content = null;
			this.fitted = true;
			this.pointers = new Map();
			this.gesture = null;
			this.settleTimer = 0;
			this.reducedMotion = window.matchMedia( '(prefers-reduced-motion: reduce)' );

			this.handlers = {
				pointerdown: ( event ) => this.pointerDown( event ),
				pointermove: ( event ) => this.pointerMove( event ),
				pointerup: ( event ) => this.pointerUp( event ),
				pointercancel: ( event ) => this.pointerUp( event ),
				wheel: ( event ) => this.wheel( event ),
				contextmenu: ( event ) => event.preventDefault()
			};
			Object.keys( this.handlers ).forEach( ( type ) => {
				viewport.addEventListener( type, this.handlers[ type ], type === 'wheel' ? { passive: false } : undefined );
			} );
			Object.assign( viewport.style, { cursor: 'grab', touchAction: 'none', userSelect: 'none' } );
		}

		/**
		 * @return {Object} tilt, spin, scale (px per unit), x, y and preset
		 *  (the matching preset name, or null)
		 */
		get state() {
			return Object.assign( {}, this.camera, { preset: math.presetAt( this.camera, this.presets ) } );
		}

		/**
		 * @param {{x: number, y: number, z: number}} size
		 * @return {number} The scale that fits content of this size at the
		 *  current angles
		 */
		fitScale( size ) {
			return math.fitScale( size, this.camera, {
				width: this.viewport.clientWidth,
				height: this.viewport.clientHeight
			}, this.margin );
		}

		/**
		 * @param {Object} content size and center in units, and buildScale
		 * @param {Object} [options]
		 * @param {boolean} [options.fit] fit the new content
		 * @param {boolean} [options.animate]
		 */
		setContent( content, options ) {
			this.content = content;
			if ( options && options.fit ) {
				this.frame();
			}
			this.update( options && options.animate );
		}

		/**
		 * Turn to a preset view and fit, the short way round.
		 *
		 * @param {string} name
		 */
		setPreset( name ) {
			const preset = this.presets[ name ];
			this.camera.tilt = preset.tilt;
			this.camera.spin = math.nearestTurn( this.camera.spin, preset.spin );
			this.frame();
			this.update( true );
		}

		fit() {
			this.frame();
			this.update( true );
		}

		/**
		 * @param {number} factor zoom about the viewport centre
		 */
		zoomBy( factor ) {
			Object.assign( this.camera, math.zoomAbout( this.camera, factor, { x: 0, y: 0 }, this.range() ) );
			this.fitted = false;
			this.update( true );
		}

		/**
		 * Call when the viewport changes size: refits content the reader has
		 * not zoomed or panned, and leaves it alone otherwise.
		 */
		resize() {
			if ( this.fitted && this.content ) {
				this.frame();
				this.update( false );
			}
		}

		destroy() {
			clearTimeout( this.settleTimer );
			Object.keys( this.handlers ).forEach( ( type ) => {
				this.viewport.removeEventListener( type, this.handlers[ type ] );
			} );
		}

		/* Internals */

		frame() {
			if ( this.content ) {
				this.camera.scale = this.fitScale( this.content.size );
			}
			this.camera.x = 0;
			this.camera.y = 0;
			this.fitted = true;
		}

		range() {
			const fit = this.content ? this.fitScale( this.content.size ) : this.camera.scale;
			return [ fit * this.zoomRange[ 0 ], fit * this.zoomRange[ 1 ] ];
		}

		/**
		 * @param {boolean} [animate] glide there; gestures never animate
		 */
		update( animate ) {
			if ( !this.content ) {
				return;
			}
			const glide = animate && !this.reducedMotion.matches;
			this.scene.style.transition = glide ? `transform ${ ANIMATION_MS }ms ${ EASE }` : 'none';
			this.scene.style.transform = math.transform( this.camera, this.content.center, this.content.buildScale );
			this.onChange( this.state );
			if ( !this.gesture ) {
				this.settle( glide ? ANIMATION_MS : 0 );
			}
		}

		settle( delay ) {
			clearTimeout( this.settleTimer );
			this.settleTimer = setTimeout( () => this.onSettle( this.state ), delay );
		}

		/**
		 * @param {{x: number, y: number}} point client coordinates
		 * @return {{x: number, y: number}} px from the viewport centre
		 */
		local( point ) {
			const rect = this.viewport.getBoundingClientRect();
			return { x: point.x - rect.left - rect.width / 2, y: point.y - rect.top - rect.height / 2 };
		}

		/**
		 * @param {PointerEvent|null} event null when a finger lifts mid-pinch
		 */
		begin( event ) {
			clearTimeout( this.settleTimer );
			const points = Array.from( this.pointers.values() );
			if ( points.length >= 2 ) {
				const [ a, b ] = points;
				this.gesture = {
					type: 'pinch',
					start: Object.assign( {}, this.camera, {
						mid: this.local( { x: ( a.x + b.x ) / 2, y: ( a.y + b.y ) / 2 } ),
						distance: Math.hypot( a.x - b.x, a.y - b.y ) || 1
					} )
				};
			} else {
				const pan = !!event && ( event.button === 1 || event.button === 2 || event.shiftKey );
				this.gesture = { type: pan ? 'pan' : 'orbit', origin: points[ 0 ], start: Object.assign( {}, this.camera ) };
			}
			this.viewport.style.cursor = this.gesture.type === 'pan' ? 'move' : 'grabbing';
		}

		pointerDown( event ) {
			if ( event.pointerType === 'mouse' && event.button > 2 ) {
				return;
			}
			this.viewport.setPointerCapture( event.pointerId );
			this.pointers.set( event.pointerId, { x: event.clientX, y: event.clientY } );
			this.begin( event );
		}

		pointerMove( event ) {
			if ( !this.pointers.has( event.pointerId ) || !this.gesture ) {
				return;
			}
			this.pointers.set( event.pointerId, { x: event.clientX, y: event.clientY } );
			const g = this.gesture;
			if ( g.type === 'pinch' ) {
				const [ a, b ] = Array.from( this.pointers.values() );
				const mid = this.local( { x: ( a.x + b.x ) / 2, y: ( a.y + b.y ) / 2 } );
				Object.assign( this.camera, math.pinch( g.start, mid, Math.hypot( a.x - b.x, a.y - b.y ), this.range() ) );
				this.fitted = false;
			} else {
				const dx = event.clientX - g.origin.x;
				const dy = event.clientY - g.origin.y;
				if ( g.type === 'pan' ) {
					this.camera.x = g.start.x + dx;
					this.camera.y = g.start.y + dy;
					this.fitted = false;
				} else {
					Object.assign( this.camera, math.orbit( g.start, dx, dy, ORBIT_RATE ) );
				}
			}
			this.update( false );
		}

		pointerUp( event ) {
			if ( !this.pointers.delete( event.pointerId ) ) {
				return;
			}
			if ( this.pointers.size ) {
				// One finger of a pinch lifted: carry on orbiting from the other.
				this.begin( null );
				return;
			}
			this.gesture = null;
			this.viewport.style.cursor = 'grab';
			this.settle( 0 );
		}

		wheel( event ) {
			event.preventDefault();
			const factor = math.wheelFactor( event.deltaY, event.deltaMode, event.ctrlKey );
			const point = this.local( { x: event.clientX, y: event.clientY } );
			Object.assign( this.camera, math.zoomAbout( this.camera, factor, point, this.range() ) );
			this.fitted = false;
			this.update( false );
			if ( !this.gesture ) {
				this.settle( WHEEL_SETTLE_MS );
			}
		}
	}

	module.exports = OrbitCamera;
}() );
