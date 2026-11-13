/*
 * Gadget: dimensionsDialog — the full view of an object's dimensions that the
 * dimensions gadget opens: a 3D scene comparing the object with people,
 * everyday objects and cargo containers, and a check of which container it
 * fits. Hidden; the dimensions gadget loads it on the first click, so readers
 * who never open it never download it. Exports open( subject, mode, opener ).
 *
 * [[MediaWiki:Gadget-dimensionsDialog.js]]
 * [[MediaWiki:Gadget-dimensions-geometry.js]]
 * [[MediaWiki:Gadget-dimensionsDialog.css]]
 *
 * Compare always uses the physical size and Fit the stowed size, falling back
 * to whichever exists.
 */
( function () {
	'use strict';

	const geo = require( './dimensions-geometry.js' );
	const OrbitCamera = require( 'ext.gadget.orbitCamera' );

	const P = 'gadget-dimensions';
	// The narrow layout's breakpoint in Gadget-dimensionsDialog.css.
	const NARROW = '(max-width: 719px)';

	// Codex icons from the gadget definition's codexIcons option: SVG content
	// for a 20px viewBox, keyed by name. 20px is Codex's medium size, 16px small.
	const icons = require( './icons.json' );
	const icon = ( name, size ) => `<svg width="${ size || 20 }" height="${ size || 20 }" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">${ icons[ name ] }</svg>`;

	const MODE_LABELS = [ [ 'compare', 'Compare' ], [ 'fit', 'Fit' ] ];
	// The narrow view menu: the presets worth a row.
	const MENU_VIEWS = [ [ '3d', '3D' ], [ 'top', 'Top' ], [ 'side', 'Side' ], [ 'front', 'Front' ] ];
	const VIEW_NAMES = { '3d': '3D', top: 'Top', side: 'Side', side2: 'Side', front: 'Front', back: 'Back' };
	// Flat views, where a scale bar measures true lengths.
	const FLAT_VIEWS = [ 'top', 'side', 'side2', 'front', 'back' ];
	const ACCENTS = 3;

	// View cube, 44px a side. Each face's label is upright as seen from its own
	// view (+y and -y Side, +x Back, -x Front). Top corners are the 3D angle
	// from each diagonal, bottom corners the level view along it.
	const CUBE_HALF = 22;
	const CUBE_FACES = [
		[ 'top', 'Top', `translateZ(${ CUBE_HALF }px)` ],
		[ 'side', 'Side', `rotateX(-90deg) translateZ(${ CUBE_HALF }px)` ],
		[ 'side2', 'Side', `rotateX(90deg) rotateZ(180deg) translateZ(${ CUBE_HALF }px)` ],
		[ 'back', 'Back', `rotateY(90deg) rotateZ(-90deg) translateZ(${ CUBE_HALF }px)` ],
		[ 'front', 'Front', `rotateY(-90deg) rotateZ(90deg) translateZ(${ CUBE_HALF }px)` ]
	];
	const CUBE_CORNERS = [
		[ '3d', -1, 1, 1 ], [ 'iso2', 1, 1, 1 ], [ 'iso3', 1, -1, 1 ], [ 'iso4', -1, -1, 1 ],
		[ 'lvl1', -1, 1, -1 ], [ 'lvl2', 1, 1, -1 ], [ 'lvl3', 1, -1, -1 ], [ 'lvl4', -1, -1, -1 ]
	];

	/**
	 * @param {string} tag
	 * @param {string} [className]
	 * @param {Object} [attrs] attribute values; false or null omits one
	 * @param {Array<Node|string>} [children]
	 * @return {HTMLElement}
	 */
	function h( tag, className, attrs, children ) {
		const node = document.createElement( tag );
		if ( className ) {
			node.className = className;
		}
		Object.keys( attrs || {} ).forEach( ( key ) => {
			const value = attrs[ key ];
			if ( value !== false && value !== null && value !== undefined ) {
				node.setAttribute( key, value === true ? '' : String( value ) );
			}
		} );
		( children || [] ).forEach( ( child ) => {
			node.append( child );
		} );
		return node;
	}

	function iconSpan( markup ) {
		const span = h( 'span', `${ P }-icon` );
		span.innerHTML = markup;
		return span;
	}

	/**
	 * @param {string|null} preset
	 * @return {string}
	 */
	function viewName( preset ) {
		if ( !preset ) {
			return 'Custom';
		}
		return VIEW_NAMES[ preset ] || ( preset.indexOf( 'lvl' ) === 0 ? 'Level' : 'Angled' );
	}

	/**
	 * A segmented control, after Citizen's preferences picker: a radio group,
	 * so arrow keys move the choice and the group is one tab stop.
	 *
	 * @param {string} label accessible name of the group
	 * @param {Array} options [ value, text ] pairs
	 * @param {string} current
	 * @param {string} name radio group name, also the focus-key prefix
	 * @param {Function} onPick
	 * @return {HTMLElement}
	 */
	function segmented( label, options, current, name, onPick ) {
		const group = h( 'div', `${ P }-segmented`, { role: 'radiogroup', 'aria-label': label } );
		options.forEach( ( [ value, text ] ) => {
			const input = h( 'input', `${ P }-segment-input`, {
				type: 'radio',
				name: `${ P }-${ name }`,
				value,
				checked: value === current,
				'data-focus': `${ name }:${ value }`
			} );
			input.addEventListener( 'change', () => onPick( value ) );
			group.append( h( 'label', `${ P }-segment`, {}, [ input, h( 'span', `${ P }-segment-label`, {}, [ text ] ) ] ) );
		} );
		return group;
	}

	/**
	 * One cuboid: four upright faces and a lid, built at the origin and placed
	 * by left/top on the ground plane.
	 *
	 * @param {Object} item layout item: x, y, box
	 * @param {number} scale px per metre
	 * @param {string} tone neutral, accent-1…3, fits or over
	 * @param {boolean} wire draw as a translucent dashed outline
	 * @return {HTMLElement}
	 */
	function cuboid( item, scale, tone, wire ) {
		const l = Math.max( item.box.length * scale, 1.5 );
		const w = Math.max( item.box.width * scale, 1.5 );
		const ht = Math.max( item.box.height * scale, 1.5 );
		const node = h( 'div', `${ P }-cuboid ${ P }-cuboid--${ tone }${ wire ? ` ${ P }-cuboid--wire` : '' }` );
		node.style.cssText = `left:${ item.x * scale }px;top:${ item.y * scale }px;width:${ l }px;height:${ w }px`;
		const face = ( kind, left, top, width, height, transform ) => {
			const f = h( 'div', `${ P }-face ${ P }-face--${ kind }` );
			f.style.cssText = `left:${ left }px;top:${ top }px;width:${ width }px;height:${ height }px;transform:${ transform }`;
			return f;
		};
		node.append(
			face( 'long', 0, 0, l, ht, 'rotateX(90deg)' ),
			face( 'short', 0, 0, ht, w, 'rotateY(-90deg)' ),
			face( 'long', 0, w, l, ht, 'rotateX(90deg)' ),
			face( 'short', l, 0, ht, w, 'rotateY(-90deg)' ),
			face( 'top', 0, 0, l, w, `translateZ(${ ht }px)` )
		);
		return node;
	}

	/**
	 * The view cube: turns with the camera and picks views. On wide screens
	 * every face and corner is a button. On narrow ones they are too small to
	 * hit, so the cube is one button that opens a menu of the main views.
	 *
	 * @param {Function} onPick called with a preset name
	 * @return {Object} root element, update( state, transition ), menuOpen(),
	 *  closeMenu( focusButton ) and destroy()
	 */
	function viewCube( onPick ) {
		const narrow = window.matchMedia( NARROW );
		const root = h( 'div', `${ P }-cube` );
		const body = h( 'div', `${ P }-cube-body` );
		let parts = [];
		let corners = [];
		let toggle = null;
		let menu = null;
		let current = { tilt: 0, spin: 0, preset: null };

		function closeMenu( focusButton ) {
			if ( !menu ) {
				return;
			}
			menu.remove();
			menu = null;
			toggle.setAttribute( 'aria-expanded', 'false' );
			if ( focusButton ) {
				toggle.focus();
			}
		}

		function openMenu() {
			menu = h( 'div', `${ P }-viewmenu`, { role: 'menu', 'aria-label': 'View' } );
			MENU_VIEWS.forEach( ( [ key, label ] ) => {
				const on = current.preset === key;
				const item = h( 'button', `${ P }-viewmenu-item`, { type: 'button', role: 'menuitemradio', 'aria-checked': String( on ) }, [
					iconSpan( on ? icon( 'cdxIconCheck' ) : '' ),
					label
				] );
				item.addEventListener( 'click', () => {
					onPick( key );
					closeMenu( true );
				} );
				menu.append( item );
			} );
			menu.addEventListener( 'keydown', ( event ) => {
				const items = Array.from( menu.children );
				const at = items.indexOf( document.activeElement );
				const step = { ArrowDown: 1, ArrowUp: -1 }[ event.key ];
				if ( step ) {
					event.preventDefault();
					items[ ( at + step + items.length ) % items.length ].focus();
				}
			} );
			root.append( menu );
			toggle.setAttribute( 'aria-expanded', 'true' );
			( menu.querySelector( '[aria-checked="true"]' ) || menu.firstChild ).focus();
		}

		function update( state, transition ) {
			current = state;
			body.style.transition = transition;
			body.style.transform = `rotateX(${ state.tilt }deg) rotateZ(${ state.spin }deg)`;
			// Corner dots face the screen and sit a hair towards it, so the faces
			// meeting there never cut them; with no perspective that changes only
			// what draws on top, not where.
			corners.forEach( ( corner ) => {
				corner.style.transition = transition;
				corner.style.transform = `translate3d(${ corner.dataset.at }) rotateZ(${ -state.spin }deg) rotateX(${ -state.tilt }deg) translateZ(3px)`;
			} );
			parts.forEach( ( part ) => {
				const on = part.dataset.view === state.preset;
				part.classList.toggle( `${ P }-cube-current`, on );
				if ( part.tagName === 'BUTTON' ) {
					part.setAttribute( 'aria-pressed', String( on ) );
				}
			} );
			if ( toggle ) {
				toggle.setAttribute( 'aria-label', `View: ${ viewName( state.preset ) }` );
			}
		}

		function build() {
			const small = narrow.matches;
			closeMenu( false );
			const faces = CUBE_FACES.map( ( [ key, label, transform ] ) => {
				const face = small ?
					h( 'span', `${ P }-cube-face`, { 'aria-hidden': 'true' }, [ label ] ) :
					h( 'button', `${ P }-cube-face`, { type: 'button', 'aria-label': `${ label } view` }, [ label ] );
				face.style.transform = transform;
				face.dataset.view = key;
				if ( !small ) {
					face.addEventListener( 'click', () => onPick( key ) );
				}
				return face;
			} );
			corners = small ? [] : CUBE_CORNERS.map( ( [ key, sx, sy, sz ] ) => {
				const corner = h( 'button', `${ P }-cube-corner`, {
					type: 'button',
					'aria-label': key === '3d' ? '3D view' : `${ sz > 0 ? 'Angled' : 'Level' } view`
				} );
				corner.dataset.view = key;
				corner.dataset.at = `${ sx * CUBE_HALF }px, ${ sy * CUBE_HALF }px, ${ sz * CUBE_HALF }px`;
				corner.addEventListener( 'click', () => onPick( key ) );
				return corner;
			} );
			parts = faces.concat( corners );
			body.replaceChildren( ...parts );
			if ( small ) {
				toggle = h( 'button', `${ P }-cube-button`, { type: 'button', 'aria-haspopup': 'menu', 'aria-expanded': 'false' }, [ body ] );
				toggle.addEventListener( 'click', () => ( menu ? closeMenu( true ) : openMenu() ) );
				root.replaceChildren( toggle );
			} else {
				toggle = null;
				root.replaceChildren( h( 'div', `${ P }-cube-stage`, { role: 'group', 'aria-label': 'View' }, [ body ] ) );
			}
			update( current, '' );
		}

		build();
		narrow.addEventListener( 'change', build );

		return {
			root,
			update,
			menuOpen: () => !!menu,
			closeMenu,
			destroy: () => narrow.removeEventListener( 'change', build )
		};
	}

	/**
	 * @param {{name: string, physical: Object|null, stowed: Object|null}} subject
	 * @param {string} initialMode compare or fit
	 * @param {HTMLElement} opener focused again on close
	 */
	function openDialog( subject, initialMode, opener ) {
		const pageBox = {
			compare: subject.physical || subject.stowed,
			fit: subject.stowed || subject.physical
		};
		// The page's object is always in the scene; these can join it.
		const catalogue = geo.REFERENCES.slice().reverse().concat( geo.CONTAINERS );
		const byId = {};
		catalogue.forEach( ( entry ) => {
			byId[ entry.id ] = entry;
		} );
		const smallest = geo.smallestFitting( pageBox.fit );

		const state = {
			mode: initialMode,
			compared: [ geo.starterReference( pageBox.compare ).id ],
			fitId: ( smallest || geo.CONTAINERS[ geo.CONTAINERS.length - 1 ] ).id,
			adding: false
		};

		const boxOf = ( id ) => ( id === 'page' ? pageBox[ state.mode ] : byId[ id ] );
		const toneOf = ( id ) => ( id === 'page' ? 'neutral' : `accent-${ ( state.compared.indexOf( id ) % ACCENTS ) + 1 }` );

		const addListId = `${ P }-addlist`;
		const dialog = h( 'dialog', `${ P }-dialog`, { 'aria-label': 'Dimensions' } );
		const closeButton = h( 'button', `cdx-button cdx-button--weight-quiet cdx-button--icon-only cdx-button--size-large ${ P }-close`, {
			type: 'button',
			'aria-label': 'Close',
			title: 'Close'
		}, [ iconSpan( icon( 'cdxIconClose' ) ) ] );
		const sidebar = h( 'div', `${ P }-sidebar` );
		const scene = h( 'div', `${ P }-scene` );
		const scaleNote = h( 'div', `${ P }-scale`, { 'aria-hidden': 'true' } );
		// Gestures drive the camera; the view cube is the keyboard route to it.
		const viewport = h( 'div', `${ P }-viewport`, { 'aria-hidden': 'true' }, [ scene ] );
		let camera = null;
		const cube = viewCube( ( key ) => camera.setPreset( key ) );
		const stage = h( 'div', `${ P }-stage`, {}, [ viewport, scaleNote, cube.root, closeButton ] );
		dialog.append( h( 'div', `${ P }-surface`, {}, [ sidebar, stage ] ) );

		function setState( patch, focusKey ) {
			Object.assign( state, patch );
			render( focusKey );
		}

		function objectRow( name, box, tone, extra ) {
			return h( 'div', `${ P }-row`, {}, [
				h( 'span', `${ P }-swatch ${ P }-swatch--${ tone }`, { 'aria-hidden': 'true' } ),
				h( 'span', `${ P }-label`, {}, [
					h( 'span', `${ P }-name`, {}, [ name ] ),
					h( 'span', `${ P }-dims`, {}, [ geo.formatBox( box ) ] )
				] ),
				extra || ''
			] );
		}

		function renderCompareSidebar() {
			const full = state.compared.length >= geo.MAX_COMPARED;
			const list = h( 'ul', `${ P }-list` );
			state.compared.forEach( ( id ) => {
				const entry = byId[ id ];
				const remove = h( 'button', `cdx-button cdx-button--weight-quiet cdx-button--icon-only ${ P }-remove`, {
					type: 'button',
					'aria-label': `Remove ${ entry.name }`,
					title: `Remove ${ entry.name }`,
					'data-focus': `remove:${ id }`
				}, [ iconSpan( icon( 'cdxIconClose', 16 ) ) ] );
				remove.addEventListener( 'click', () => setState( { compared: state.compared.filter( ( x ) => x !== id ) }, 'add' ) );
				list.append( h( 'li', '', {}, [ objectRow( entry.name, entry, toneOf( id ), remove ) ] ) );
			} );

			// Laid out like an object row, the add icon in the swatch's place.
			const add = h( 'button', `${ P }-add`, {
				type: 'button',
				'aria-expanded': state.adding ? 'true' : 'false',
				'aria-controls': addListId,
				disabled: full,
				'data-focus': 'add'
			}, [ iconSpan( icon( 'cdxIconAdd', 16 ) ), h( 'span', '', {}, [ 'Add object' ] ) ] );
			add.addEventListener( 'click', () => setState( { adding: !state.adding } ) );

			const nodes = [
				h( 'div', `${ P }-listhead`, {}, [
					h( 'span', '', {}, [ 'Compared with' ] ),
					h( 'span', '', {}, [ `${ state.compared.length } of ${ geo.MAX_COMPARED }` ] )
				] ),
				list,
				add
			];
			if ( full ) {
				nodes.push( h( 'p', `${ P }-note`, {}, [ `Up to ${ geo.MAX_COMPARED } at a time.` ] ) );
			}
			if ( state.adding && !full ) {
				const options = h( 'ul', `${ P }-addlist`, { id: addListId } );
				catalogue.filter( ( entry ) => state.compared.indexOf( entry.id ) === -1 ).forEach( ( entry ) => {
					const option = h( 'button', `${ P }-option`, { type: 'button', 'data-focus': `option:${ entry.id }` }, [
						h( 'span', `${ P }-name`, {}, [ entry.name ] ),
						h( 'span', `${ P }-dims`, {}, [ geo.formatBox( entry ) ] )
					] );
					option.addEventListener( 'click', () => {
						const compared = geo.addCompared( state.compared, entry.id );
						setState( { compared, adding: false }, compared.length >= geo.MAX_COMPARED ? `remove:${ entry.id }` : 'add' );
					} );
					options.append( h( 'li', '', {}, [ option ] ) );
				} );
				nodes.push( options );
			}
			return nodes;
		}

		function renderFitSidebar() {
			const list = h( 'ul', `${ P }-list` );
			geo.CONTAINERS.forEach( ( container ) => {
				const check = geo.fitCheck( pageBox.fit, container );
				const row = h( 'button', `${ P }-fitrow`, {
					type: 'button',
					'aria-pressed': container.id === state.fitId ? 'true' : 'false',
					'data-focus': `fit:${ container.id }`
				}, [
					h( 'span', `${ P }-label`, {}, [
						h( 'span', `${ P }-name`, {}, [ container.name ] ),
						h( 'span', `${ P }-dims`, {}, [ geo.formatBox( container ) ] )
					] ),
					h( 'span', `${ P }-status ${ P }-status--${ check.fits ? 'fits' : 'over' }`, {}, [
						check.fits ? 'Fits' : `${ geo.formatLength( check.over ) } too big`
					] )
				] );
				row.addEventListener( 'click', () => setState( { fitId: container.id } ) );
				list.append( h( 'li', '', {}, [ row ] ) );
			} );
			return [ list ];
		}

		// What the scene holds; the camera refits only when this changes, so
		// sidebar clicks that leave the scene alone keep the reader's zoom.
		const sceneKey = () => ( state.mode === 'fit' ? `fit:${ state.fitId }` : `compare:${ state.compared.join( ',' ) }` );
		let builtKey = null;
		let builtScale = 0;
		let builtStep = 1;

		function renderScale( view ) {
			if ( FLAT_VIEWS.indexOf( view.preset ) === -1 ) {
				scaleNote.replaceChildren( `Grid square: ${ geo.formatLength( builtStep ) }` );
				return;
			}
			const bar = geo.barStep( view.scale, viewport.clientWidth < 480 ? 110 : 150 );
			const rule = h( 'span', `${ P }-bar` );
			rule.style.width = `${ bar * view.scale }px`;
			scaleNote.replaceChildren( rule, geo.formatLength( bar ) );
		}

		/**
		 * Build the cuboids and grid at a scale, px per metre.
		 *
		 * @param {Object} options
		 * @param {number} [options.scale] rebuild at this scale and keep the
		 *  camera; without it, fit the scene
		 * @param {boolean} [options.animate]
		 */
		function buildScene( options ) {
			let layout;
			let tones;
			if ( state.mode === 'fit' ) {
				const container = byId[ state.fitId ];
				const fits = geo.fitCheck( pageBox.fit, container ).fits;
				layout = geo.layoutFit( pageBox.fit, container );
				tones = [ [ 'neutral', false ], [ fits ? 'fits' : 'over', true ] ];
			} else {
				// The row recedes from the camera along x, so shortest first keeps
				// small objects from hiding behind tall ones.
				const ids = [ 'page' ].concat( state.compared ).sort( ( a, b ) => boxOf( a ).height - boxOf( b ).height );
				layout = geo.layoutRow( ids.map( boxOf ) );
				tones = ids.map( ( id ) => [ toneOf( id ), false ] );
			}
			const { min, max } = layout.bounds;
			const size = { x: max.x - min.x, y: max.y - min.y, z: max.z - min.z };
			const center = { x: ( min.x + max.x ) / 2, y: ( min.y + max.y ) / 2, z: ( min.z + max.z ) / 2 };
			const scale = options.scale || camera.fitScale( size );
			if ( !isFinite( scale ) || scale <= 0 ) {
				return;
			}
			builtScale = scale;
			builtStep = geo.gridStep( scale, 18 );

			const pad = Math.max( size.x, size.y ) * 0.12;
			const grid = h( 'div', `${ P }-grid` );
			grid.style.cssText = `left:${ ( min.x - pad ) * scale }px;top:${ ( min.y - pad ) * scale }px;` +
				`width:${ ( size.x + 2 * pad ) * scale }px;height:${ ( size.y + 2 * pad ) * scale }px;` +
				`background-size:${ builtStep * scale }px ${ builtStep * scale }px`;
			scene.replaceChildren( grid, ...layout.items.map( ( item, i ) => cuboid( item, scale, tones[ i ][ 0 ], tones[ i ][ 1 ] ) ) );
			camera.setContent( { size, center, buildScale: scale }, { fit: !options.scale, animate: options.animate } );
		}

		function render( focusKey ) {
			const active = document.activeElement;
			const keep = focusKey || ( active && dialog.contains( active ) && active.dataset.focus );

			sidebar.replaceChildren(
				objectRow( subject.name, pageBox[ state.mode ], 'neutral' ),
				segmented( 'Mode', MODE_LABELS, state.mode, 'mode', ( mode ) => setState( { mode, adding: false } ) ),
				...( state.mode === 'fit' ? renderFitSidebar() : renderCompareSidebar() )
			);
			const key = sceneKey();
			if ( key !== builtKey ) {
				buildScene( { animate: builtKey !== null } );
				builtKey = key;
			}

			if ( keep ) {
				const target = dialog.querySelector( `[data-focus="${ keep }"]` );
				if ( target && !target.disabled ) {
					target.focus();
				} else if ( focusKey ) {
					closeButton.focus();
				}
			}
		}

		let frame = 0;
		const observer = new ResizeObserver( () => {
			cancelAnimationFrame( frame );
			frame = requestAnimationFrame( () => camera.resize() );
		} );

		closeButton.addEventListener( 'click', () => dialog.close() );
		// A click on the backdrop lands on the dialog element itself.
		dialog.addEventListener( 'click', ( event ) => {
			if ( event.target === dialog ) {
				dialog.close();
			}
		} );
		// Pressing anywhere outside the view menu closes it, a drag included.
		dialog.addEventListener( 'pointerdown', ( event ) => {
			if ( cube.menuOpen() && !cube.root.contains( event.target ) ) {
				cube.closeMenu( false );
			}
		}, true );
		// Escape closes the add list or the view menu before the dialog.
		dialog.addEventListener( 'cancel', ( event ) => {
			if ( state.adding ) {
				event.preventDefault();
				setState( { adding: false }, 'add' );
			} else if ( cube.menuOpen() ) {
				event.preventDefault();
				cube.closeMenu( true );
			}
		} );
		dialog.addEventListener( 'close', () => {
			observer.disconnect();
			cancelAnimationFrame( frame );
			camera.destroy();
			cube.destroy();
			dialog.remove();
			if ( opener && opener.isConnected ) {
				opener.focus();
			}
		} );

		document.body.append( dialog );
		dialog.showModal();
		camera = new OrbitCamera( viewport, scene, {
			presets: geo.VIEWS,
			initial: '3d',
			margin: { x: 0.8, y: 0.68 },
			onChange: ( view ) => {
				// The cube glides when the camera does and snaps when it is dragged.
				cube.update( view, scene.style.transition );
				renderScale( view );
			},
			// CSS scale also scales the 1px edges and the grid, so once still,
			// rebuild at the scale the reader zoomed to.
			onSettle: ( view ) => {
				if ( Math.abs( view.scale / builtScale - 1 ) > 0.01 ) {
					buildScene( { scale: view.scale } );
				}
			}
		} );
		render( `mode:${ state.mode }` );
		observer.observe( viewport );
	}

	module.exports = { open: openDialog };
}() );
