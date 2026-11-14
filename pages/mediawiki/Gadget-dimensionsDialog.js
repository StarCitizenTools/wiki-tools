/*
 * Gadget: dimensionsDialog — the full view of an object's dimensions that the
 * dimensions gadget opens: a 3D scene comparing the object with people,
 * everyday objects and cargo containers, and a check of which container or
 * vehicle cargo grid it fits. Hidden; the dimensions gadget loads it on the
 * first click, so readers who never open it never download it. Exports
 * open( subject, mode, opener ).
 *
 * [[MediaWiki:Gadget-dimensionsDialog.js]]
 * [[MediaWiki:Gadget-dimensions-geometry.js]]
 * [[MediaWiki:Gadget-dimensions-spaces.js]]
 * [[MediaWiki:Gadget-dimensionsDialog.css]]
 *
 * Compare always uses the physical size and Fit the stowed size, falling back
 * to whichever exists. Fit's cargo grids come from the cargo_grid Bucket
 * table, one query per group the first time that group opens or a search
 * needs it, kept for the rest of the page view.
 */
( function () {
	'use strict';

	const geo = require( './dimensions-geometry.js' );
	const spaces = require( './dimensions-spaces.js' );
	const OrbitCamera = require( 'ext.gadget.orbitCamera' );

	const P = 'gadget-dimensions';
	// A fit's status by how the object is set down (geo.placeIn).
	const FIT_POSES = { upright: 'Fits', side: 'Fits on its side', end: 'Fits on end' };
	// A vehicle reads as its best grid's verdict (geo.secureCheck states).
	const OWNER_VERDICTS = [
		{ state: 'secured', status: 'Secured', tone: 'fits' },
		{ state: 'fits', status: 'Fits', tone: 'fits' },
		{ state: 'loose', status: 'Loose', tone: 'loose' }
	];
	// The narrow layout's breakpoint in Gadget-dimensionsDialog.css.
	const NARROW = '(max-width: 719px)';

	// Codex icons from the gadget definition's codexIcons option: SVG content
	// for a 20px viewBox, keyed by name. 20px is Codex's medium size, 16px small.
	// A direction-sensitive icon (Next, Previous) is an object instead: ltr and
	// rtl shapes, or one ltr shape with shouldFlip, which RTL pages mirror.
	const icons = require( './icons.json' );
	const icon = ( name, size ) => {
		let content = icons[ name ];
		let flip = false;
		if ( typeof content !== 'string' ) {
			const rtl = document.documentElement.dir === 'rtl';
			flip = rtl && !content.rtl && !!content.shouldFlip;
			content = ( rtl && content.rtl ) || content.ltr || content.default || '';
		}
		return `<svg width="${ size || 20 }" height="${ size || 20 }" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"${ flip ? ' style="transform:scaleX(-1)"' : '' }>${ content }</svg>`;
	};

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

	// Each group's owners, fetched once a page view. groupLoads holds the
	// request while it runs; a failed one is forgotten so the next try refetches.
	const groupLoads = {};
	const groupOwners = {};

	/**
	 * @param {Object} group an entry of spaces.GROUPS
	 * @param {boolean} [retry] ask past a cached copy, after a failure
	 * @return {Promise<Object[]>} the group's owners
	 */
	function loadGroup( group, retry ) {
		if ( !groupLoads[ group.id ] ) {
			const params = new URLSearchParams( spaces.requestParams( group, retry ? String( Date.now() ) : undefined ) );
			groupLoads[ group.id ] = fetch( `${ mw.config.get( 'wgScriptPath' ) }/api.php?${ params }` )
				.then( ( response ) => ( response.ok ? response.json() : Promise.reject( new Error( `HTTP ${ response.status }` ) ) ) )
				.then( ( data ) => {
					if ( !Array.isArray( data.bucket ) ) {
						throw new Error( 'No Bucket rows in the response' );
					}
					groupOwners[ group.id ] = spaces.ownersFromRows( data.bucket, group );
					return groupOwners[ group.id ];
				} )
				.catch( ( error ) => {
					delete groupLoads[ group.id ];
					throw error;
				} );
		}
		return groupLoads[ group.id ];
	}

	/**
	 * @param {number} scu
	 * @return {string} e.g. '1,170 SCU'
	 */
	function formatScu( scu ) {
		return `${ scu.toLocaleString( 'en' ) } SCU`;
	}

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
	 * The quiet icon button an object row carries: Remove after a compared
	 * object, Back before an opened vehicle.
	 *
	 * @param {string} iconName a codexIcons name
	 * @param {string} label accessible name and tooltip
	 * @param {string} focusKey
	 * @return {HTMLElement}
	 */
	function rowButton( iconName, label, focusKey ) {
		return h( 'button', `cdx-button cdx-button--weight-quiet cdx-button--icon-only ${ P }-rowbutton`, {
			type: 'button',
			'aria-label': label,
			title: label,
			'data-focus': focusKey
		}, [ iconSpan( icon( iconName, 16 ) ) ] );
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
	 * @param {boolean} [floor] rule the floor in SCU squares, for a cargo grid
	 * @return {HTMLElement}
	 */
	function cuboid( item, scale, tone, wire, floor ) {
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
		if ( floor ) {
			const ruled = face( 'floor', 0, 0, l, w, 'none' );
			ruled.style.backgroundSize = `${ geo.SCU_EDGE * scale }px ${ geo.SCU_EDGE * scale }px`;
			node.prepend( ruled );
		}
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
			// What the scene puts the object in: { container } names a standard
			// container; { owner, key, space } one of an owner's cargo grids.
			sel: { container: ( smallest || geo.CONTAINERS[ geo.CONTAINERS.length - 1 ] ).id },
			query: '',
			// Fit's groups; only Standard containers, which needs no request, starts open.
			open: { containers: true },
			// The owner whose cargo grids the sidebar lists in place of the groups.
			opened: null,
			adding: false
		};
		// This dialog's view of each group's request: pending while it runs, so
		// another toggle or keystroke starts no second one; failed after an error
		// until the reader retries.
		const pending = {};
		const failed = {};

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
		// Fit's verdict on the selected space, over the scene's top left. The
		// selected row carries the same status for assistive technology.
		const verdict = h( 'div', `${ P }-verdict`, { 'aria-hidden': 'true' } );
		// Gestures drive the camera; the view cube is the keyboard route to it.
		const viewport = h( 'div', `${ P }-viewport`, { 'aria-hidden': 'true' }, [ scene ] );
		let camera = null;
		const cube = viewCube( ( key ) => camera.setPreset( key ) );
		const stage = h( 'div', `${ P }-stage`, {}, [ viewport, verdict, scaleNote, cube.root, closeButton ] );
		// The list and, on narrow screens only, its handle: there the panel lies
		// over the scene's lower part and slides down to show more of it.
		const grabber = h( 'button', `${ P }-grabber`, {
			type: 'button',
			'aria-label': 'Expand the view',
			'aria-expanded': 'false'
		}, [ h( 'span', `${ P }-grabber-bar` ) ] );
		const panel = h( 'div', `${ P }-panel`, {}, [ grabber, sidebar ] );
		const surface = h( 'div', `${ P }-surface`, {}, [ panel, stage ] );
		const narrow = window.matchMedia( NARROW );
		dialog.append( surface );

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
				const remove = rowButton( 'cdxIconClose', `Remove ${ entry.name }`, `remove:${ id }` );
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

		// Fit's search field outlives renders, so typing never loses focus or
		// the caret; a keystroke refills only the results below it.
		const searchInput = h( 'input', `${ P }-search-input`, {
			type: 'search',
			placeholder: 'Search vehicles and containers',
			'aria-label': 'Search what to fit it into',
			autocomplete: 'off',
			spellcheck: 'false',
			'data-focus': 'search'
		} );
		const searchField = h( 'div', `${ P }-search`, {}, [ iconSpan( icon( 'cdxIconSearch', 16 ) ), searchInput ] );
		const results = h( 'div', `${ P }-results` );

		const fitTarget = () => state.sel.space || byId[ state.sel.container ];
		const tooBig = ( check ) => `${ geo.formatLength( check.over ) } too big`;
		const statusText = ( check ) => ( check.fits ? FIT_POSES[ check.pose ] : tooBig( check ) );
		const gridCount = ( n ) => `${ n } cargo ${ n === 1 ? 'grid' : 'grids' }`;

		/**
		 * @param {Object} check from geo.secureCheck
		 * @return {Object} the grid row's status and tone, and the verdict's
		 *  title and line
		 */
		function gridVerdict( check ) {
			if ( check.state === 'secured' ) {
				return { status: 'Secured', tone: 'fits', title: 'Secured', line: 'Fits, and the grid locks it down.' };
			}
			if ( check.state === 'loose' ) {
				return { status: 'Loose', tone: 'loose', title: 'Loose', line: 'Fits the space, but the grid won’t lock it down.' };
			}
			if ( check.state === 'fits' ) {
				return { status: FIT_POSES[ check.pose ], tone: 'fits', title: FIT_POSES[ check.pose ], line: '' };
			}
			return { status: tooBig( check ), tone: 'over', title: 'Too big', line: `${ tooBig( check ) } for this grid.` };
		}

		/**
		 * @param {Object} row focus key, pressed, name, sub, status, tone (fits,
		 *  loose or over), onClick, and optionally count (identical grids) and
		 *  chevron (opens a list)
		 * @return {HTMLElement}
		 */
		function fitRow( row ) {
			const name = h( 'span', `${ P }-name`, {}, [ row.name ] );
			const button = h( 'button', `${ P }-fitrow`, {
				type: 'button',
				'aria-pressed': row.pressed ? 'true' : 'false',
				'data-focus': row.focus
			}, [
				h( 'span', `${ P }-label`, {}, [
					row.count > 1 ? h( 'span', `${ P }-nameline`, {}, [ name, h( 'span', `${ P }-count`, {}, [ `×${ row.count }` ] ) ] ) : name,
					h( 'span', `${ P }-dims`, {}, [ row.sub ] )
				] ),
				h( 'span', `${ P }-status ${ P }-status--${ row.tone }`, {}, [ row.status ] ),
				row.chevron ? iconSpan( icon( 'cdxIconNext', 16 ) ) : ''
			] );
			button.addEventListener( 'click', row.onClick );
			return h( 'li', '', {}, [ button ] );
		}

		function containerRow( container ) {
			const check = geo.fitCheck( pageBox.fit, container );
			return fitRow( {
				focus: `fit:${ container.id }`,
				pressed: state.sel.container === container.id,
				name: container.name,
				sub: geo.formatBox( container ),
				status: statusText( check ),
				tone: check.fits ? 'fits' : 'over',
				onClick: () => setState( { sel: { container: container.id } } )
			} );
		}

		// An owner opens to its grids and puts the object in the first that
		// secures it, else the first it fits, so the scene answers before the
		// reader picks one.
		function openOwner( owner ) {
			const patch = { opened: owner };
			if ( state.sel.owner !== owner.name ) {
				const entries = spaces.groupSpaces( owner.spaces );
				const states = entries.map( ( entry ) => geo.secureCheck( pageBox.fit, entry.space ).state );
				const at = OWNER_VERDICTS.map( ( verdict ) => states.indexOf( verdict.state ) ).find( ( i ) => i !== -1 );
				const first = entries[ at === undefined ? entries.length - 1 : at ];
				patch.sel = { owner: owner.name, key: first.key, space: first.space };
			}
			navigate( 'forward' );
			setState( patch, 'back' );
		}

		// The kind leads the second line only in search results, where groups
		// mix; under a group's header it would repeat the header.
		function ownerRow( owner, withKind ) {
			const states = owner.spaces.map( ( space ) => geo.secureCheck( pageBox.fit, space ).state );
			const best = OWNER_VERDICTS.find( ( verdict ) => states.indexOf( verdict.state ) !== -1 ) || { status: 'Too big', tone: 'over' };
			return fitRow( {
				focus: `owner:${ owner.name }`,
				pressed: state.sel.owner === owner.name,
				name: owner.name,
				sub: ( withKind ? `${ owner.kind } · ` : '' ) + `${ gridCount( owner.spaces.length ) } · ${ formatScu( spaces.totalCapacity( owner.spaces ) ) }`,
				status: best.status,
				tone: best.tone,
				chevron: true,
				onClick: () => openOwner( owner )
			} );
		}

		function skeletons() {
			return h( 'div', `${ P }-skeletons`, { 'aria-hidden': 'true' }, [
				h( 'span', `${ P }-skeleton` ),
				h( 'span', `${ P }-skeleton` ),
				h( 'span', `${ P }-skeleton` )
			] );
		}

		function loadError( text, groups ) {
			const retry = h( 'button', `cdx-button cdx-button--weight-quiet cdx-button--size-small ${ P }-retry`, {
				type: 'button',
				'data-focus': `retry:${ groups.map( ( group ) => group.id ).join( ',' ) }`
			}, [ 'Retry' ] );
			retry.addEventListener( 'click', () => {
				groups.forEach( ensureLoaded );
				refreshResults();
			} );
			return h( 'div', `${ P }-loaderror`, { role: 'alert' }, [ h( 'span', '', {}, [ text ] ), retry ] );
		}

		/**
		 * Start a group's request if it has none, and refill the results when it
		 * settles.
		 *
		 * @param {Object} group an entry of spaces.GROUPS
		 */
		function ensureLoaded( group ) {
			if ( groupOwners[ group.id ] || pending[ group.id ] ) {
				return;
			}
			const retry = !!failed[ group.id ];
			pending[ group.id ] = true;
			failed[ group.id ] = false;
			loadGroup( group, retry ).then( () => {
				pending[ group.id ] = false;
				refreshResults();
			}, () => {
				pending[ group.id ] = false;
				failed[ group.id ] = true;
				refreshResults();
			} );
		}

		/**
		 * One collapsible group: its header, and when open its rows, or skeleton
		 * rows while they load.
		 *
		 * @param {string} id
		 * @param {string} label
		 * @param {Object|null} group an entry of spaces.GROUPS; null for the
		 *  standard containers, which are built in
		 * @return {HTMLElement[]}
		 */
		function groupSection( id, label, group ) {
			const expanded = !!state.open[ id ];
			const owners = group && groupOwners[ group.id ];
			const loading = !!group && expanded && !owners && !failed[ group.id ];
			const bodyId = `${ P }-group-${ id }`;
			const head = h( 'button', `${ P }-group`, {
				type: 'button',
				'aria-expanded': expanded ? 'true' : 'false',
				'aria-controls': bodyId,
				'aria-busy': loading ? 'true' : false,
				'data-focus': `group:${ id }`
			}, [ iconSpan( icon( 'cdxIconNext', 16 ) ), h( 'span', '', {}, [ label ] ) ] );
			head.addEventListener( 'click', () => {
				state.open = Object.assign( {}, state.open, { [ id ]: !expanded } );
				if ( !expanded && group ) {
					ensureLoaded( group );
				}
				refreshResults();
			} );
			if ( !expanded ) {
				return [ head ];
			}
			let body;
			if ( !group ) {
				body = h( 'ul', `${ P }-list`, {}, geo.CONTAINERS.map( containerRow ) );
			} else if ( owners ) {
				body = h( 'ul', `${ P }-list`, {}, owners.map( ( owner ) => ownerRow( owner, false ) ) );
			} else if ( failed[ group.id ] ) {
				body = loadError( `Couldn't load ${ label.toLowerCase() }.`, [ group ] );
			} else {
				body = skeletons();
			}
			body.id = bodyId;
			return [ head, body ];
		}

		// Search covers the containers and every group loaded so far; the
		// groups still loading show as skeleton rows under the matches.
		function searchNodes( query ) {
			let owners = [];
			const missing = [];
			let loading = false;
			spaces.GROUPS.forEach( ( group ) => {
				if ( groupOwners[ group.id ] ) {
					owners = owners.concat( groupOwners[ group.id ] );
				} else if ( failed[ group.id ] ) {
					missing.push( group );
				} else {
					loading = true;
				}
			} );
			const hits = spaces.search( geo.CONTAINERS.concat( owners ), query );
			const nodes = [];
			if ( hits.length ) {
				nodes.push( h( 'ul', `${ P }-list`, {}, hits.map( ( entry ) => ( entry.spaces ? ownerRow( entry, true ) : containerRow( entry ) ) ) ) );
			}
			if ( loading ) {
				nodes.push( skeletons() );
			} else if ( !hits.length ) {
				nodes.push( h( 'p', `${ P }-note`, {}, [ `Nothing matches “${ query.trim() }”.` ] ) );
			}
			if ( missing.length ) {
				nodes.push( loadError( 'Some vehicles couldn\'t be loaded.', missing ) );
			}
			return nodes;
		}

		function fillResults() {
			const query = state.query.trim();
			if ( query ) {
				results.replaceChildren( ...searchNodes( query ) );
				return;
			}
			results.replaceChildren(
				...groupSection( 'containers', 'Standard containers', null ),
				...[].concat( ...spaces.GROUPS.map( ( group ) => groupSection( group.id, group.label, group ) ) )
			);
		}

		// Refill the results alone, after a keystroke, a group toggle or a
		// request settling, keeping focus on the control that had it.
		function refreshResults() {
			if ( !results.isConnected ) {
				return;
			}
			const active = document.activeElement;
			const keep = active && results.contains( active ) && active.dataset.focus;
			fillResults();
			const target = keep && results.querySelector( `[data-focus="${ keep }"]` );
			if ( target ) {
				target.focus();
			} else if ( keep ) {
				searchInput.focus();
			}
		}

		function renderOwner( owner ) {
			const back = rowButton( 'cdxIconPrevious', 'Back', 'back' );
			back.addEventListener( 'click', () => {
				navigate( 'back' );
				setState( { opened: null }, `owner:${ owner.name }` );
			} );
			const total = owner.spaces.length;
			const rows = spaces.groupSpaces( owner.spaces ).map( ( entry ) => {
				const result = gridVerdict( geo.secureCheck( pageBox.fit, entry.space ) );
				return fitRow( {
					focus: `grid:${ entry.key }`,
					pressed: state.sel.owner === owner.name && state.sel.key === entry.key,
					name: `${ formatScu( entry.space.capacity ) } grid`,
					count: entry.count,
					sub: geo.formatBox( entry.space ) + ( entry.space.external ? ' · External' : '' ),
					status: result.status,
					tone: result.tone,
					onClick: () => setState( { sel: { owner: owner.name, key: entry.key, space: entry.space } } )
				} );
			} );
			// The owner reads as the row it was picked from, and its header is an
			// object row like a compared object's, Back leading where Remove trails.
			return [
				h( 'div', `${ P }-row ${ P }-ownerhead`, {}, [
					back,
					h( 'div', `${ P }-label ${ P }-owner`, {}, [
						h( 'span', `${ P }-name`, {}, [ owner.name ] ),
						h( 'span', `${ P }-dims`, {}, [ `${ owner.kind } · ${ formatScu( spaces.totalCapacity( owner.spaces ) ) } in ${ gridCount( total ) }` ] )
					] )
				] ),
				h( 'ul', `${ P }-list`, {}, rows )
			];
		}

		// Fit's sidebar below the mode switch is one pane: the groups and search,
		// or an owner's grids. Opening an owner pushes its pane in from the right
		// while the list's slides out to the left, and Back reverses it; the
		// leaving pane lies over the arriving one until its animation ends.
		const panes = h( 'div', `${ P }-panes` );
		const reduceMotion = window.matchMedia( '(prefers-reduced-motion: reduce)' );
		// Set just before the render that moves between the panes.
		let navigation = null;
		// The list's scroll position, put back when Back returns to it.
		let listScroll = 0;
		let leavingPane = null;

		function navigate( direction ) {
			navigation = direction;
			if ( direction === 'forward' ) {
				listScroll = sidebar.scrollTop;
			}
		}

		function renderFitSidebar() {
			const pane = h( 'div', `${ P }-pane` );
			if ( state.opened ) {
				pane.append( ...renderOwner( state.opened ) );
			} else {
				fillResults();
				pane.append( searchField, results );
			}
			const leaving = navigation && !reduceMotion.matches && panes.firstElementChild;
			if ( leaving ) {
				const toward = navigation === 'forward' ? 'left' : 'right';
				leaving.className = `${ P }-pane ${ P }-pane--leaving ${ P }-pane--to-${ toward }`;
				leaving.inert = true;
				pane.classList.add( `${ P }-pane--from-${ navigation === 'forward' ? 'right' : 'left' }` );
				panes.replaceChildren( pane, leaving );
				const done = () => leaving.remove();
				leaving.addEventListener( 'animationend', done, { once: true } );
				setTimeout( done, 400 );
				leavingPane = leaving;
			} else {
				panes.replaceChildren( pane );
			}
			return [ panes ];
		}

		// What the scene holds; the camera refits only when this changes, so
		// sidebar clicks that leave the scene alone keep the reader's zoom.
		const selKey = () => state.sel.container || `${ state.sel.owner }#${ state.sel.key }`;
		const sceneKey = () => ( state.mode === 'fit' ? `fit:${ selKey() }` : `compare:${ state.compared.join( ',' ) }` );
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
				const target = fitTarget();
				const tone = state.sel.owner ?
					gridVerdict( geo.secureCheck( pageBox.fit, target ) ).tone :
					( geo.fitCheck( pageBox.fit, target ).fits ? 'fits' : 'over' );
				layout = geo.layoutFit( pageBox.fit, target );
				tones = [ [ 'neutral', false, false ], [ tone, true, !!state.sel.owner ] ];
			} else {
				// The row recedes from the camera along x, so shortest first keeps
				// small objects from hiding behind tall ones.
				const ids = [ 'page' ].concat( state.compared ).sort( ( a, b ) => boxOf( a ).height - boxOf( b ).height );
				layout = geo.layoutRow( ids.map( boxOf ) );
				tones = ids.map( ( id ) => [ toneOf( id ), false, false ] );
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

			// The floor fills the viewport seen from above and fades out before
			// its edge, which a tilted view brings on screen. It is kept that
			// small on purpose: tilting brings more of it into view, and its
			// raster cost grows with the area on screen. A grid line runs
			// through the first item's corner: in Fit, the container's, so the
			// floor carries on a cargo grid's SCU ruling. Below one SCU, every
			// SCU line is drawn stronger than the squares between.
			const half = Math.hypot( viewport.clientWidth, viewport.clientHeight ) * 0.75 / scale;
			const corner = { x: center.x - half, y: center.y - half };
			const anchor = layout.items[ 0 ];
			const major = Math.max( builtStep, geo.SCU_EDGE ) * scale;
			const minor = builtStep * scale;
			const offset = `${ ( anchor.x - corner.x ) * scale }px ${ ( anchor.y - corner.y ) * scale }px`;
			const grid = h( 'div', `${ P }-grid` );
			grid.style.cssText = `left:${ corner.x * scale }px;top:${ corner.y * scale }px;` +
				`width:${ 2 * half * scale }px;height:${ 2 * half * scale }px;` +
				`background-size:100% 100%,${ major }px ${ major }px,${ major }px ${ major }px,${ minor }px ${ minor }px,${ minor }px ${ minor }px;` +
				`background-position:0 0,${ offset },${ offset },${ offset },${ offset }`;
			scene.replaceChildren( grid, ...layout.items.map( ( item, i ) => cuboid( item, scale, tones[ i ][ 0 ], tones[ i ][ 1 ], tones[ i ][ 2 ] ) ) );
			camera.setContent( { size, center, buildScale: scale }, { fit: !options.scale, animate: options.animate } );
		}

		// Keep fitted content clear of the verdict above it and, on narrow
		// screens, of the panel over the scene's lower part.
		function syncInset() {
			let bottom = 0;
			if ( narrow.matches ) {
				bottom = surface.classList.contains( `${ P }-surface--full` ) ? grabber.offsetHeight : panel.offsetHeight;
			}
			camera.setInset( verdict.hidden ? 0 : verdict.offsetTop + verdict.offsetHeight + 8, bottom );
		}

		function renderVerdict() {
			verdict.hidden = state.mode !== 'fit';
			if ( verdict.hidden ) {
				syncInset();
				return;
			}
			const target = fitTarget();
			let result;
			if ( state.sel.owner ) {
				result = gridVerdict( geo.secureCheck( pageBox.fit, target ) );
			} else {
				const check = geo.fitCheck( pageBox.fit, target );
				result = check.fits ?
					{ tone: 'fits', title: FIT_POSES[ check.pose ], line: '' } :
					{ tone: 'over', title: 'Too big', line: `${ tooBig( check ) } for this container.` };
			}
			verdict.replaceChildren(
				h( 'span', `${ P }-verdict-title ${ P }-verdict-title--${ result.tone }`, {}, [ result.title ] ),
				result.line ? h( 'span', `${ P }-verdict-line`, {}, [ result.line ] ) : ''
			);
			syncInset();
		}

		function render( focusKey ) {
			const active = document.activeElement;
			const keep = focusKey || ( active && dialog.contains( active ) && active.dataset.focus );
			const moving = navigation;
			const oldScroll = sidebar.scrollTop;

			sidebar.replaceChildren(
				objectRow( subject.name, pageBox[ state.mode ], 'neutral' ),
				segmented( 'Mode', MODE_LABELS, state.mode, 'mode', ( mode ) => setState( { mode, adding: false } ) ),
				...( state.mode === 'fit' ? renderFitSidebar() : renderCompareSidebar() )
			);
			navigation = null;
			// An owner's grids start at the top; Back finds the list where it was
			// left. The leaving pane shifts by the scroll change so it stays put.
			if ( moving ) {
				sidebar.scrollTop = moving === 'forward' ? 0 : listScroll;
				if ( leavingPane ) {
					leavingPane.style.top = `${ sidebar.scrollTop - oldScroll }px`;
					leavingPane = null;
				}
			}
			renderVerdict();
			const key = sceneKey();
			if ( key !== builtKey ) {
				buildScene( { animate: builtKey !== null } );
				builtKey = key;
			}

			if ( keep ) {
				const target = dialog.querySelector( `[data-focus="${ keep }"]` );
				if ( target && !target.disabled ) {
					target.focus( { preventScroll: !!moving } );
				} else if ( focusKey ) {
					// Back to an owner whose group is collapsed lands on the search.
					( searchInput.isConnected ? searchInput : closeButton ).focus();
				}
			}
		}

		// A search loads every group it covers. Escape clears a search before it
		// closes the dialog.
		searchInput.addEventListener( 'input', () => {
			state.query = searchInput.value;
			if ( state.query.trim() ) {
				spaces.GROUPS.forEach( ensureLoaded );
			}
			refreshResults();
		} );
		searchInput.addEventListener( 'keydown', ( event ) => {
			if ( event.key === 'Escape' && searchInput.value ) {
				event.preventDefault();
				searchInput.value = '';
				state.query = '';
				refreshResults();
			}
		} );

		let frame = 0;
		const observer = new ResizeObserver( () => {
			cancelAnimationFrame( frame );
			frame = requestAnimationFrame( () => {
				syncInset();
				camera.resize();
			} );
		} );

		// The grabber slides the panel down over the scene, as far as the
		// bottom of the sheet, by a transform alone: a drag lays nothing out
		// again. Let go, the panel settles at the nearer of its two places and
		// the camera refits once; a tap, Enter or Space switches between them.
		let drag = null;
		let dragged = false;
		let dragFrame = 0;
		function setExpanded( on ) {
			panel.style.transform = '';
			surface.classList.toggle( `${ P }-surface--full`, on );
			grabber.setAttribute( 'aria-expanded', String( on ) );
			grabber.setAttribute( 'aria-label', on ? 'Shrink the view' : 'Expand the view' );
			syncInset();
		}
		grabber.addEventListener( 'pointerdown', ( event ) => {
			const max = panel.offsetHeight - grabber.offsetHeight;
			const start = surface.classList.contains( `${ P }-surface--full` ) ? max : 0;
			drag = { y: event.clientY, start, offset: start, max, moved: false };
			grabber.setPointerCapture( event.pointerId );
			surface.classList.add( `${ P }-surface--dragging` );
		} );
		grabber.addEventListener( 'pointermove', ( event ) => {
			if ( !drag ) {
				return;
			}
			const dy = event.clientY - drag.y;
			drag.moved = drag.moved || Math.abs( dy ) > 4;
			if ( !drag.moved ) {
				return;
			}
			drag.offset = Math.max( 0, Math.min( drag.max, drag.start + dy ) );
			if ( !dragFrame ) {
				dragFrame = requestAnimationFrame( () => {
					dragFrame = 0;
					if ( drag ) {
						panel.style.transform = `translateY(${ drag.offset }px)`;
					}
				} );
			}
		} );
		const endDrag = () => {
			if ( !drag ) {
				return;
			}
			const { moved, offset, max } = drag;
			drag = null;
			cancelAnimationFrame( dragFrame );
			dragFrame = 0;
			surface.classList.remove( `${ P }-surface--dragging` );
			if ( moved ) {
				setExpanded( offset > max / 2 );
				dragged = true;
			}
		};
		grabber.addEventListener( 'pointerup', endDrag );
		grabber.addEventListener( 'pointercancel', endDrag );
		// The click that ends a drag is not a tap.
		grabber.addEventListener( 'click', () => {
			if ( dragged ) {
				dragged = false;
				return;
			}
			setExpanded( grabber.getAttribute( 'aria-expanded' ) !== 'true' );
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
