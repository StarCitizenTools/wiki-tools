/*
 * Gadget: SCW AG Grid renderers
 *
 * Registers Star Citizen Wiki-specific AG Grid column types with the AGGrid
 * extension through its `ext.aggrid.register` hook. The extension fires that hook
 * fresh before every grid mounts (after the grid bundle lazy-loads), so a handler
 * registered at normal startup is always in place first.
 *
 * Loaded only on pages that embed a grid: the gadget is gated in
 * MediaWiki:Gadgets-definition by a category condition. Its companion stylesheet
 * MediaWiki:Gadget-aggridRenderers.css styles the cells these renderers build.
 *
 * The Lua side packs one value object per row and resolves every file/URL target
 * server-side; these renderers only build safe DOM from the resolved value.
 *
 * Column types
 *  - scwEntityCard: a compact "entity" cell — thumbnail + eyebrow + title, with
 *    the eyebrow glyph rendered as a decorative right-edge watermark and beside
 *    each value in the set filter. Value shape:
 *      { image: {src,width,alt,href}|null, title, titleHref,
 *        eyebrow, eyebrowFull, eyebrowHref, eyebrowIcon: {src,...}|null }
 *    eyebrow = display label; eyebrowFull = the set-filter value (falls back to
 *    eyebrow); eyebrowIcon = the brand glyph.
 *  - scwStackedValue: a primary line over an optional muted secondary line, with
 *    a raw number for sort / the number filter. Value shape:
 *      { value: <number>, text: <primary string>, sub: <secondary string>|null }
 */
( function () {
	'use strict';

	// Mirror the extension's safe-scheme check (renderers.js): relative, hash, or
	// http(s) only. hrefs are MediaWiki-generated server-side; this is defence in
	// depth against a hand-built value.
	var SAFE_HREF = /^(?:https?:|\/(?!\/)|\.\/|#)/;

	// Wrap a node in an anchor when href is a safe scheme; otherwise return it bare.
	function anchor( href, child ) {
		if ( typeof href !== 'string' || !SAFE_HREF.test( href ) ) {
			return child;
		}
		var a = document.createElement( 'a' );
		a.href = href;
		a.appendChild( child );
		return a;
	}

	// Build an <img> from a resolved thumb value, or null when absent.
	function imageNode( thumb, className ) {
		if ( !thumb || !thumb.src ) {
			return null;
		}
		var img = document.createElement( 'img' );
		img.src = thumb.src;
		img.alt = thumb.alt || '';
		img.className = className;
		if ( thumb.width ) {
			img.width = thumb.width;
		}
		return img;
	}

	// Build the eyebrow icon: a span painted as a CSS mask tinted with
	// currentColor (theme-aware), so a monochrome brand glyph stays visible on any
	// skin. Only safe-scheme URLs are accepted into the mask.
	function iconNode( thumb, className ) {
		// Reject anything but a safe scheme, and any quote/paren that could break
		// out of the url("...") token the URL is interpolated into below.
		if ( !thumb || !thumb.src || !SAFE_HREF.test( thumb.src ) || /["')]/.test( thumb.src ) ) {
			return null;
		}
		var span = document.createElement( 'span' );
		span.className = className;
		span.style.setProperty( '--scw-entitycard-icon', 'url("' + thumb.src + '")' );
		return span;
	}

	function buildCard( v ) {
		var card = document.createElement( 'div' );
		card.className = 'scw-entitycard';
		if ( !v ) {
			return card;
		}

		// Decorative brand glyph: a faint watermark behind the content, vertically
		// centred and aligned to the cell's right edge. Painted as a currentColor
		// mask so it adapts to the theme. Purely decorative -> hidden from AT.
		var watermark = iconNode( v.eyebrowIcon, 'scw-entitycard__watermark' );
		if ( watermark ) {
			watermark.setAttribute( 'aria-hidden', 'true' );
			card.appendChild( watermark );
		}

		// Media: thumbnail, linked to the entity page.
		var media = imageNode( v.image, 'scw-entitycard__image' );
		if ( media ) {
			var mediaWrap = document.createElement( 'span' );
			mediaWrap.className = 'scw-entitycard__media';
			mediaWrap.appendChild( anchor( v.titleHref, media ) );
			card.appendChild( mediaWrap );
		}

		var body = document.createElement( 'span' );
		body.className = 'scw-entitycard__body';

		// Eyebrow: text only (the glyph is rendered as the watermark above),
		// linked when an href is given.
		if ( v.eyebrow ) {
			var eyebrow = document.createElement( 'span' );
			eyebrow.className = 'scw-entitycard__eyebrow';
			eyebrow.textContent = v.eyebrow;
			body.appendChild( anchor( v.eyebrowHref, eyebrow ) );
		}

		// Title: primary line, linked to the entity page.
		var title = document.createElement( 'span' );
		title.className = 'scw-entitycard__title';
		title.textContent = v.title || '';
		body.appendChild( anchor( v.titleHref, title ) );

		card.appendChild( body );
		return card;
	}

	// A stacked value cell: a primary line over an optional muted secondary line.
	// The value carries pre-formatted display strings plus the raw number used for
	// sort and the number filter:
	//   { value: <number>, text: <primary string>, sub: <secondary string>|null }
	function buildStack( v ) {
		var el = document.createElement( 'div' );
		el.className = 'scw-stackedvalue';
		if ( !v ) {
			return el;
		}
		var primary = document.createElement( 'span' );
		primary.className = 'scw-stackedvalue__primary';
		primary.textContent = v.text != null ? v.text : '';
		el.appendChild( primary );
		if ( v.sub ) {
			var sub = document.createElement( 'span' );
			sub.className = 'scw-stackedvalue__secondary';
			sub.textContent = v.sub;
			el.appendChild( sub );
		}
		return el;
	}

	// The raw number behind a stacked value (for sort / filter), or null.
	function stackNumber( v ) {
		return v && typeof v.value === 'number' ? v.value : null;
	}

	// eyebrow label -> resolved eyebrow-icon src, harvested from scwEntityCard rows
	// on mount. The card's set-filter itemRenderer reads it to show the glyph beside
	// each value. Global (icons are the same across grids); merged per mount.
	var eyebrowIcons = Object.create( null );

	// Record each scwEntityCard column's eyebrow -> icon src from the loaded rows.
	function harvestEyebrowIcons( api, gridOptions ) {
		var fields = ( gridOptions.columnDefs || [] ).filter( function ( c ) {
			var t = c && c.type;
			return t === 'scwEntityCard' || ( Array.isArray( t ) && t.indexOf( 'scwEntityCard' ) !== -1 );
		} ).map( function ( c ) {
			return c.field;
		} ).filter( Boolean );
		if ( !fields.length ) {
			return;
		}
		api.forEachNode( function ( node ) {
			var d = node.data;
			if ( !d ) {
				return;
			}
			fields.forEach( function ( f ) {
				var v = d[ f ];
				var label = v && ( v.eyebrowFull || v.eyebrow );
				if ( label && v.eyebrowIcon && v.eyebrowIcon.src ) {
					eyebrowIcons[ label ] = v.eyebrowIcon.src;
				}
			} );
		} );
	}

	// Set-filter itemRenderer for a card column: the eyebrow's glyph (when known)
	// beside the value label, painted as a currentColor mask like the card itself.
	function eyebrowFilterItem( params ) {
		var row = document.createElement( 'span' );
		row.className = 'scw-entitycard-filter';
		var src = eyebrowIcons[ params.label ];
		if ( src && SAFE_HREF.test( src ) && !/["')]/.test( src ) ) {
			var icon = document.createElement( 'span' );
			icon.className = 'scw-entitycard-filter__icon';
			icon.style.setProperty( '--scw-entitycard-icon', 'url("' + src + '")' );
			row.appendChild( icon );
		}
		var label = document.createElement( 'span' );
		label.className = 'scw-entitycard-filter__label';
		label.textContent = params.label != null ? params.label : '';
		row.appendChild( label );
		return row;
	}

	mw.hook( 'ext.aggrid.gridReady' ).add( function ( api, el, gridOptions ) {
		harvestEyebrowIcons( api, gridOptions );
	} );

	mw.hook( 'ext.aggrid.register' ).add( function ( reg ) {
		reg.columnTypes.scwEntityCard = {
			cellRenderer: function ( params ) {
				return buildCard( params.value );
			},
			// Sort / quick-search / CSV export key on the title (ship name); the set
			// filter lists the eyebrow (e.g. manufacturer) via filterValueGetter,
			// decoupled from the display scalar (AGGrid#17). cellRenderer is
			// independent of both.
			valueFormatter: function ( params ) {
				return ( params.value && params.value.title ) || '';
			},
			filterValueGetter: function ( params ) {
				var v = params.data && params.data[ params.colDef.field ];
				return ( v && ( v.eyebrowFull || v.eyebrow ) ) || null;
			},
			// Show the eyebrow glyph beside each value in the set filter.
			filterParams: {
				itemRenderer: eyebrowFilterItem
			},
			comparator: function ( a, b ) {
				return String( ( a && a.title ) || '' )
					.localeCompare( String( ( b && b.title ) || '' ) );
			}
		};

		reg.columnTypes.scwStackedValue = {
			cellRenderer: function ( params ) {
				return buildStack( params.value );
			},
			// Display/quick-search/export use the primary string; sort and the
			// number filter operate on the raw number (filterValueGetter so the
			// built-in agNumberColumnFilter compares numerically, not on the object).
			valueFormatter: function ( params ) {
				return ( params.value && params.value.text ) || '';
			},
			filterValueGetter: function ( params ) {
				return stackNumber( params.data && params.data[ params.colDef.field ] );
			},
			comparator: function ( a, b ) {
				var an = stackNumber( a );
				var bn = stackNumber( b );
				if ( an === null ) {
					return bn === null ? 0 : -1;
				}
				if ( bn === null ) {
					return 1;
				}
				return an - bn;
			}
		};
	} );
}() );
