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
 *  - scwBadge: a BadgeLua-style pill. Value shape:
 *      { text, variant: 'error'|'success'|'warning'|null }
 *  - scwBadgeList: a wrapping row of BadgeLua-style pills, each with an optional
 *    currentColor mask icon and optional whole-pill link. Value shape:
 *      { list: [{ text, variant, iconSrc, href }] }
 *  - scwSignedBar: a signed number drawn as a bar growing from a centre line,
 *    leaning the way that HELPS regardless of sign, with the figure beside it.
 *    Value shape:
 *      { value: <number>, text: <signed string>, good: <boolean|undefined> }
 *    good absent = no inherent good side: the bar leans by sign, drawn neutral.
 *    Bar length is |value| / colDef.scwBarMax, scaled on the column so two rows
 *    compare; it does not rescale when rows are filtered.
 *  - scwSmart: a plain text column with numeric-aware sort and per-cell right-
 *    align of numeric-looking values. Cell value is a display string (no object).
 *  - scwBoolean: an icon-only tri-state boolean (check / cross / help), tinted per
 *    state with visually-hidden text + title + data-state for sort / filter / AT /
 *    scrapers. Value shape:
 *      { text, state: 'yes'|'no'|'unknown', iconSrc }
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

	// Decode HTML entities in a display string (notably the literal "&#160;" the SMW
	// formatter emits for nbsp) by round-tripping through a detached <textarea>. This
	// is browser-native decoding; it never executes markup.
	var scwDecodeEl = document.createElement( 'textarea' );
	function scwDecode( s ) {
		// Callers pass an already-stringified value (see scwClean); s is always a string.
		if ( s.indexOf( '&' ) === -1 ) {
			return s;
		}
		scwDecodeEl.innerHTML = s;
		return scwDecodeEl.value;
	}

	// Normalise a cell value to clean text: stringify, decode entities, fold nbsp to
	// a normal space, collapse runs, and trim. Numbers stringify straight through.
	function scwClean( v ) {
		if ( v === null || v === undefined ) {
			return '';
		}
		var s = typeof v === 'string' ? v : String( v );
		s = scwDecode( s );
		return s.replace( / /g, ' ' ).replace( /\s+/g, ' ' ).replace( /^\s+|\s+$/g, '' );
	}

	// The numeric value of a cell, or null when it is not numeric. RULE: numeric iff,
	// after cleaning, the value is a LEADING number (optional sign, decimals,
	// thousands commas) followed by an optional TRAILING unit token (a run with no
	// digits: ' m/s', ' kg', ' SCU', '°/s', '🗡️'). 'S2' / 'Gr. 3' / '$1,500' have the
	// number after a non-digit prefix, so they are NON-numeric and sort
	// alphabetically ( 'S1' < 'S10' < 'S2' ). One predictable rule for every column.
	function scwNumericPart( v ) {
		if ( typeof v === 'number' ) {
			return isFinite( v ) ? v : null;
		}
		var s = scwClean( v );
		if ( s === '' ) {
			return null;
		}
		var m = s.match( /^([+-]?[0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:[^0-9]*)$/ );
		if ( !m ) {
			return null;
		}
		var n = parseFloat( m[ 1 ].replace( /,/g, '' ) );
		return isNaN( n ) ? null : n;
	}

	function scwLooksNumeric( v ) {
		return scwNumericPart( v ) !== null;
	}

	// Numeric when both sides are numeric (tie-break by localeCompare so equal
	// numbers with different unit text stay stable); alphabetical otherwise.
	function scwNumericAwareCompare( a, b ) {
		var an = scwNumericPart( a );
		var bn = scwNumericPart( b );
		if ( an !== null && bn !== null ) {
			if ( an < bn ) {
				return -1;
			}
			if ( an > bn ) {
				return 1;
			}
		}
		return scwClean( a ).localeCompare( scwClean( b ) );
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

	// Signed-bar cell: a centre-anchored track with the fill leaning the helpful
	// way, and the figure beside it. The figure sits OUTSIDE the track rather than
	// over the fill -- overlaying them makes the long bars unreadable.
	function buildSignedBar( v, max ) {
		var el = document.createElement( 'div' );
		el.className = 'scw-signedbar';
		if ( !v || typeof v.value !== 'number' ) {
			return el;
		}
		var track = document.createElement( 'span' );
		track.className = 'scw-signedbar__track';
		var fill = document.createElement( 'span' );
		fill.className = 'scw-signedbar__fill';
		// A floor keeps a very small value visible as a mark rather than nothing;
		// the half-width cap is the centre line, so a bar never crosses it.
		var scale = typeof max === 'number' && max > 0 ? max : 1;
		var ratio = Math.min( 1, Math.abs( v.value ) / scale );
		fill.style.width = Math.max( 3, ratio * 50 ) + '%';
		// good tells which side helps; without it the sign decides and the fill is
		// left neutral, so an undirected stat is never coloured as a verdict.
		var leansRight = v.good === undefined ? v.value > 0 : v.good;
		if ( leansRight ) {
			fill.style.left = '50%';
		} else {
			fill.style.right = '50%';
		}
		if ( v.good === true ) {
			fill.classList.add( 'scw-signedbar__fill--good' );
		} else if ( v.good === false ) {
			fill.classList.add( 'scw-signedbar__fill--bad' );
		}
		track.appendChild( fill );
		el.appendChild( track );
		var num = document.createElement( 'span' );
		num.className = 'scw-signedbar__value';
		if ( v.good === true ) {
			num.classList.add( 'scw-signedbar__value--good' );
		} else if ( v.good === false ) {
			num.classList.add( 'scw-signedbar__value--bad' );
		}
		num.textContent = v.text != null ? v.text : '';
		el.appendChild( num );
		return el;
	}

	// Badge cell, styled to match Module:BadgeLua (.t-badge). Value: { text,
	// variant } where variant is 'error' | 'success' | 'warning' (else a neutral
	// base badge). An absent value renders an empty cell.
	var BADGE_VARIANTS = { error: true, success: true, warning: true };
	// One badge pill: text + optional currentColor mask icon + optional whole-pill
	// link. Shared by scwBadge (single) and scwBadgeList.
	function buildBadgeEl( b ) {
		var badge = document.createElement( 'span' );
		badge.className = 't-badge';
		if ( b.variant && BADGE_VARIANTS[ b.variant ] ) {
			badge.classList.add( 't-badge--' + b.variant );
		}
		if ( b.iconSrc && SAFE_HREF.test( b.iconSrc ) && !/["')]/.test( b.iconSrc ) ) {
			var icon = document.createElement( 'span' );
			icon.className = 't-badge__icon';
			icon.style.setProperty( '--t-badge-icon', 'url("' + b.iconSrc + '")' );
			badge.appendChild( icon );
		}
		var text = document.createElement( 'span' );
		text.className = 't-badge__text';
		text.textContent = b.text;
		badge.appendChild( text );
		if ( b.href && SAFE_HREF.test( b.href ) ) {
			var a = document.createElement( 'a' );
			a.href = b.href;
			a.appendChild( badge );
			return a;
		}
		return badge;
	}

	// scwBadge cell. Value: { text, variant }. Absent value -> empty cell.
	function buildBadge( v ) {
		if ( !v || !v.text ) {
			return document.createTextNode( '' );
		}
		return buildBadgeEl( v );
	}

	// scwBadgeList cell. Value: { list: [{ text, variant, iconSrc, href }] }. A
	// wrapping row of pills; absent/empty list renders an empty cell.
	function buildBadgeList( v ) {
		var wrap = document.createElement( 'span' );
		wrap.className = 't-badge-list';
		var list = v && v.list;
		if ( list ) {
			list.forEach( function ( b ) {
				if ( b && b.text ) {
					wrap.appendChild( buildBadgeEl( b ) );
				}
			} );
		}
		return wrap;
	}

	// scwBoolean cell. Value: { text, state, iconSrc }. Icon-only render matching
	// Module:Boolean.render: the visible glyph is a currentColor mask tinted per
	// state, machine-readable three ways like the infobox -- a visually-hidden text
	// span (sort / set-filter / AT), a title (hover), and data-state (scrapers / AI
	// agents query [data-state]). Absent value -> empty cell.
	function buildBoolean( v ) {
		if ( !v || !v.text ) {
			return document.createTextNode( '' );
		}
		var state = v.state || 'unknown';
		var wrap = document.createElement( 'span' );
		wrap.className = 't-boolean-cell t-boolean-cell--' + state;
		wrap.setAttribute( 'data-state', state );
		wrap.setAttribute( 'title', v.text );
		if ( v.iconSrc && SAFE_HREF.test( v.iconSrc ) && !/["')]/.test( v.iconSrc ) ) {
			var icon = document.createElement( 'span' );
			icon.className = 't-boolean-cell__icon';
			icon.style.setProperty( '--t-boolean-cell-icon', 'url("' + v.iconSrc + '")' );
			wrap.appendChild( icon );
		}
		var sr = document.createElement( 'span' );
		sr.className = 't-boolean-cell__sr';
		sr.textContent = v.text;
		wrap.appendChild( sr );
		return wrap;
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
			// Sort and CSV export key on the title (ship name). The *column*
			// filter value is chosen by colDef.scwCardFilterOn: 'title' (text
			// filter on the name, used by Module:DataGrid) or 'eyebrow' (set
			// filter on e.g. the manufacturer). Unset uses the eyebrow when
			// present, else the title, so PledgeVehicleGrid (which always has an
			// eyebrow and sets no flag) filters by manufacturer as before.
			valueFormatter: function ( params ) {
				return ( params.value && params.value.title ) || '';
			},
			filterValueGetter: function ( params ) {
				var v = params.data && params.data[ params.colDef.field ];
				if ( !v ) {
					return null;
				}
				if ( params.colDef.scwCardFilterOn === 'title' ) {
					return v.title || null;
				}
				if ( params.colDef.scwCardFilterOn === 'eyebrow' ) {
					return v.eyebrowFull || v.eyebrow || null;
				}
				return v.eyebrowFull || v.eyebrow || v.title || null;
			},
			// Quick-search keys on BOTH the ship name and the manufacturer label,
			// independent of which the column filter (filterValueGetter, above)
			// keys on. AG Grid derives quick-filter text from the *filter* value
			// unless getQuickFilterText is set -- and the card's filter value is
			// only one of the two (manufacturer on PledgeVehicleGrid, title on
			// Module:DataGrid), so without this the other half of the card would
			// be unsearchable. valueFormatter is never consulted by quick-search.
			// Read the packed value from row data: params.value here is the filter
			// scalar, not the card object.
			getQuickFilterText: function ( params ) {
				var v = params.data && params.data[ params.colDef.field ];
				if ( !v ) {
					return '';
				}
				return [ v.title, v.eyebrowFull || v.eyebrow ]
					.filter( Boolean )
					.join( ' ' );
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
			// Display uses the primary string, and so does CSV export (valueFormatter).
			// Sort, the number filter, AND quick-search all key on the raw number
			// (filterValueGetter): the number filter's agNumberColumnFilter compares
			// numerically rather than on the object, and quick-search -- which derives
			// its text from the filter value, never valueFormatter -- therefore matches
			// the underlying number (e.g. "1500"), not the formatted "$1,500" display
			// or the secondary line. That is the intended behaviour for these price
			// columns; add a getQuickFilterText here if the formatted text ever needs
			// to be searchable.
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

		reg.columnTypes.scwSignedBar = {
			cellRenderer: function ( params ) {
				return buildSignedBar( params.value, params.colDef && params.colDef.scwBarMax );
			},
			// Display, CSV export and quick-search all use the signed text; sort and
			// the number filter key on the raw number, so "widest charge window" is a
			// header click and a range filter reads in percent.
			valueFormatter: function ( params ) {
				return ( params.value && params.value.text ) || '';
			},
			filterValueGetter: function ( params ) {
				return stackNumber( params.data && params.data[ params.colDef.field ] );
			},
			getQuickFilterText: function ( params ) {
				var v = params.data && params.data[ params.colDef.field ];
				return ( v && v.text ) || '';
			},
			comparator: function ( a, b ) {
				var an = stackNumber( a );
				var bn = stackNumber( b );
				// Blanks sink in both directions: a module that does not touch a stat
				// is not "the lowest", and sorting should not bury the rows that do.
				if ( an === null ) {
					return bn === null ? 0 : -1;
				}
				if ( bn === null ) {
					return 1;
				}
				return an - bn;
			}
		};

		reg.columnTypes.scwBadge = {
			cellRenderer: function ( params ) {
				return buildBadge( params.value );
			},
			// Sort / set filter key on the badge text.
			valueFormatter: function ( params ) {
				return ( params.value && params.value.text ) || '';
			},
			// Quick-search on the badge text. AG Grid hands getQuickFilterText the
			// column's *formatted* value (params.value is the string, not the packed
			// object), so read the object straight from row data -- same pattern as
			// scwEntityCard -- to pull its .text reliably.
			getQuickFilterText: function ( params ) {
				var v = params.data && params.data[ params.colDef.field ];
				return ( v && v.text ) || '';
			},
			comparator: function ( a, b ) {
				return String( ( a && a.text ) || '' )
					.localeCompare( String( ( b && b.text ) || '' ) );
			}
		};

		reg.columnTypes.scwBoolean = {
			cellRenderer: function ( params ) {
				return buildBoolean( params.value );
			},
			// Sort / set filter key on the boolean text (same as scwBadge).
			valueFormatter: function ( params ) {
				return ( params.value && params.value.text ) || '';
			},
			// Quick-search on the boolean text (Yes / No / Unknown). Read the packed
			// object from row data, not params.value (AG Grid passes the formatted
			// value string there, not the object) -- same pattern as scwEntityCard.
			getQuickFilterText: function ( params ) {
				var v = params.data && params.data[ params.colDef.field ];
				return ( v && v.text ) || '';
			},
			comparator: function ( a, b ) {
				return String( ( a && a.text ) || '' )
					.localeCompare( String( ( b && b.text ) || '' ) );
			}
		};

		// Multi-value badge list (Module:DataGrid `kind=effect`). Value:
		// { list: [{ text, variant, iconSrc, href }] }. Sort / quick-search on the
		// joined labels; the set filter splits per badge text via filterValueGetter.
		reg.columnTypes.scwBadgeList = {
			cellRenderer: function ( params ) {
				return buildBadgeList( params.value );
			},
			valueFormatter: function ( params ) {
				var l = params.value && params.value.list;
				return l ? l.map( function ( b ) { return b.text; } ).join( ', ' ) : '';
			},
			filterValueGetter: function ( params ) {
				var v = params.data && params.data[ params.colDef.field ];
				var l = v && v.list;
				return l ? l.map( function ( b ) { return b.text; } ) : null;
			},
			comparator: function ( a, b ) {
				function join( v ) {
					return ( v && v.list ) ? v.list.map( function ( x ) { return x.text; } ).join( ', ' ) : '';
				}
				return join( a ).localeCompare( join( b ) );
			}
		};

		// Generic numeric-aware text column for browse tables (Module:DataGrid). The
		// Lua side packs a plain display string; this type sorts numeric-looking
		// values numerically and right-aligns them per cell, with no Lua typing.
		reg.columnTypes.scwSmart = {
			comparator: function ( a, b ) {
				return scwNumericAwareCompare( a, b );
			},
			cellClassRules: {
				'ag-right-aligned-cell': function ( params ) {
					return scwLooksNumeric( params.value );
				}
			},
			valueFormatter: function ( params ) {
				return params.value == null ? '' : String( params.value );
			}
		};
	} );
}() );
