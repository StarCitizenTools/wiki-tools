/*
 * Gadget: Blame — git blame for articles. Colours every word by the editor who
 * last changed it; words a template or module produced are hatched instead.
 *
 * [[MediaWiki:Gadget-blame.js]]
 * [[MediaWiki:Gadget-blame-text.js]]
 * [[MediaWiki:Gadget-blame.css]]
 *
 * Use Special:Export/<page>?history=1 because of server performance, less
 * network requests, and it having no limits. Fallback to Revisions API if it
 * fails (e.g. missing permissions, errors, etc.)
 *
 * Parsoid is considered but not used. Its source offsets cannot attribute template
 * parameter prose or the reference list, and its HTML can carry unexpanded
 * {{#parsoidfragment}} markers (T432547).
 *
 * Codex components are avoided for bundle size, as you need to load the whole
 * module as gadget.
 */
( function () {
	'use strict';

	const text = require( './blame-text.js' );
	const teleportTarget = require( 'mediawiki.page.ready' ).teleportTarget;

	// Time-based, not every N revisions: per-revision cost varies by orders of
	// magnitude, so a fixed count still leaves 50 ms+ tasks.
	const SLICE_MS = 16;
	const PALETTE_SIZE = 8;
	const HIDDEN = '(hidden)';
	// Past the cap the unmatched middle is credited to the newer revision, so a
	// cap below a plausible scattered sweep hands one editor text they never
	// wrote. Myers costs O(cap^2) once exhausted.
	const MAX_D_REVISION = 5000;
	// Page-to-source diverges much further, since template output has no source
	// counterpart at all: 3565 measured on an infobox fed from an API. Exhausting
	// this hatches the WHOLE page rather than the excess.
	const MAX_D_ALIGN = 20000;
	// <style> is here because TemplateStyles injects it inside .mw-parser-output.
	// The reference LIST is deliberately absent: moveRefs makes it attributable.
	//
	// Template classes must NOT be added. Their parameter values stay in the
	// source stream, and the alignment is a monotone LCS, so excluding the
	// rendered region strands those tokens for the first body word that matches.
	const UNPAINTED = '.mw-editsection, sup.reference, .mw-cite-backlink, style, script, .gadget-blame-popover, .gadget-blame-legend';
	// cdxIconClose, inlined: @wikimedia/codex-icons is not a ResourceLoader module.
	const ICON_CLOSE = 'M16.707 4.707 11.414 10l5.293 5.293-1.414 1.414L10 11.414l-5.293 5.293-1.414-1.414L8.586 10 3.293 4.707l1.414-1.414L10 8.586l5.293-5.293z';

	const config = mw.config.get( [
		'wgIsArticle', 'wgArticleId', 'wgAction', 'wgPageName', 'wgRevisionId',
		'wgCurRevisionId'
	] );
	if ( !config.wgIsArticle || !config.wgArticleId || config.wgAction !== 'view' ) {
		return;
	}

	let historyPromise = null;
	const page = { on: false, token: 0, painted: [], legend: null, revById: null };

	function el( tag, attrs, children ) {
		const node = document.createElement( tag );
		Object.keys( attrs || {} ).forEach( ( k ) => {
			if ( k === 'class' ) {
				node.className = attrs[ k ];
			} else if ( k === 'text' ) {
				node.textContent = attrs[ k ];
			} else {
				node.setAttribute( k, attrs[ k ] );
			}
		} );
		( children || [] ).forEach( ( c ) => {
			if ( c ) {
				node.appendChild( typeof c === 'string' ? document.createTextNode( c ) : c );
			}
		} );
		return node;
	}

	function link( href, label, cls ) {
		return el( 'a', { href, class: cls || '', text: label } );
	}

	function iconButton( label, pathD ) {
		const svgNs = 'http://www.w3.org/2000/svg';
		const svg = document.createElementNS( svgNs, 'svg' );
		svg.setAttribute( 'width', '20' );
		svg.setAttribute( 'height', '20' );
		svg.setAttribute( 'viewBox', '0 0 20 20' );
		svg.setAttribute( 'aria-hidden', 'true' );
		const path = document.createElementNS( svgNs, 'path' );
		path.setAttribute( 'd', pathD );
		svg.appendChild( path );
		return el( 'button', {
			type: 'button',
			class: 'gadget-blame__button',
			'aria-label': label,
			title: label
		}, [ svg ] );
	}

	function message( type, children ) {
		return el( 'div', {
			class: 'gadget-blame__notice gadget-blame__notice--' + type,
			'aria-live': 'polite'
		}, children );
	}

	function formatDate( iso ) {
		const d = new Date( iso );
		return isNaN( d ) ? iso : d.toLocaleString( undefined, { dateStyle: 'medium', timeStyle: 'short' } );
	}

	function userLink( name ) {
		if ( !name ) {
			return el( 'span', { class: 'gadget-blame__meta', text: HIDDEN } );
		}
		const isIp = mw.util.isIPAddress ? mw.util.isIPAddress( name ) : /^\d+\.\d+\.\d+\.\d+$/.test( name );
		const target = isIp ? 'Special:Contributions/' + name : 'User:' + name;
		return link( mw.util.getUrl( target ), name, 'gadget-blame__user' );
	}

	function contentRoot() {
		return document.querySelector( '#mw-content-text .mw-parser-output' );
	}

	function tick() {
		return new Promise( ( resolve ) => setTimeout( resolve ) );
	}

	function textOf( parent, selector ) {
		const n = parent.querySelector( selector );
		return n ? n.textContent : '';
	}

	function parseExport( xml ) {
		const doc = new DOMParser().parseFromString( xml, 'application/xml' );
		if ( doc.querySelector( 'parsererror' ) ) {
			throw new Error( 'blame-export-parse' );
		}
		const revs = [];
		doc.querySelectorAll( 'revision' ).forEach( ( r ) => {
			const t = r.querySelector( ':scope > text' );
			const hidden = !t || t.getAttribute( 'deleted' ) === 'deleted';
			revs.push( {
				id: Number( textOf( r, ':scope > id' ) ),
				parentid: Number( textOf( r, ':scope > parentid' ) || 0 ),
				timestamp: textOf( r, ':scope > timestamp' ),
				user: textOf( r, ':scope > contributor > username' ) || textOf( r, ':scope > contributor > ip' ),
				comment: textOf( r, ':scope > comment' ),
				sha1: textOf( r, ':scope > sha1' ) || ( t && t.getAttribute( 'sha1' ) ) || '',
				// null, not '': revision-deleted text is excluded, not an empty page.
				text: hidden ? null : t.textContent
			} );
		} );
		revs.sort( ( a, b ) => ( a.timestamp < b.timestamp ? -1 : a.timestamp > b.timestamp ? 1 : a.id - b.id ) );
		return revs;
	}

	function fetchExport() {
		const url = mw.util.getUrl( 'Special:Export/' + config.wgPageName, { history: 1 } );
		return fetch( url, { credentials: 'same-origin' } ).then( ( r ) => {
			if ( !r.ok ) {
				throw new Error( 'blame-export-http-' + r.status );
			}
			return r.text();
		} ).then( parseExport );
	}

	function fetchViaApi() {
		const api = new mw.Api();
		const revs = [];
		function batch( cont ) {
			const params = Object.assign( {
				action: 'query',
				prop: 'revisions',
				titles: config.wgPageName,
				rvprop: 'ids|timestamp|user|comment|sha1|content',
				rvslots: 'main',
				rvlimit: 50,
				rvdir: 'newer',
				formatversion: 2
			}, cont || {} );
			return api.get( params ).then( ( data ) => {
				const p = data.query.pages[ 0 ];
				( p.revisions || [] ).forEach( ( r ) => {
					const slot = r.slots && r.slots.main;
					revs.push( {
						id: r.revid,
						parentid: r.parentid || 0,
						timestamp: r.timestamp,
						user: r.user || '',
						comment: r.comment || '',
						sha1: r.sha1 || '',
						text: slot && !slot.texthidden && !r.texthidden &&
							typeof slot.content === 'string' ? slot.content : null
					} );
				} );
				return data.continue ? batch( data.continue ) : revs;
			} );
		}
		return batch();
	}

	function loadHistory() {
		if ( !historyPromise ) {
			historyPromise = fetchExport()
				.catch( fetchViaApi )
				.then( ( revs ) => (
					// $wgExportAllowHistory=false: a one-revision export with a parent.
					revs.length === 1 && revs[ 0 ].parentid > 0 ? fetchViaApi() : revs
				) )
				.catch( ( e ) => {
					historyPromise = null;
					throw e;
				} );
		}
		return historyPromise;
	}

	function setBody( body, children ) {
		body.textContent = '';
		children.forEach( ( c ) => c && body.appendChild( c ) );
	}

	function loading( body, label ) {
		setBody( body, [
			el( 'div', { class: 'gadget-blame__bar', role: 'progressbar', 'aria-label': label } ),
			el( 'div', { class: 'gadget-blame__meta', text: label } )
		] );
	}

	function renderError( body, err ) {
		setBody( body, [ message( 'error', [
			'Could not load the page history (' + ( err && err.message ? err.message : 'unknown error' ) + ').'
		] ) ] );
	}

	// The popover attribute gives light dismissal, Escape and the top layer. Only
	// placement is ours: CSS anchor positioning would do it declaratively but is
	// not yet in Firefox or Safari.
	let popoverEl = null;
	let popoverAnchor = null;

	function setActive( on ) {
		if ( popoverAnchor ) {
			popoverAnchor.classList.toggle( 'gadget-blame-w--active', on );
		}
	}

	function place() {
		if ( !popoverEl || !popoverAnchor ) {
			return;
		}
		const gap = 8;
		const a = popoverAnchor.getBoundingClientRect();
		const p = popoverEl.getBoundingClientRect();
		let top = a.bottom + gap;
		if ( top + p.height > window.innerHeight - gap && a.top - gap - p.height > gap ) {
			top = a.top - gap - p.height;
		}
		const left = Math.max( gap, Math.min( a.left, window.innerWidth - p.width - gap ) );
		popoverEl.style.top = Math.max( gap, top ) + 'px';
		popoverEl.style.left = left + 'px';
	}

	function hidePopover() {
		if ( !popoverEl ) {
			return;
		}
		if ( popoverEl.hidePopover ) {
			if ( popoverEl.matches( ':popover-open' ) ) {
				popoverEl.hidePopover();
			}
		} else {
			popoverEl.classList.remove( 'gadget-blame-popover--open' );
		}
		setActive( false );
		popoverAnchor = null;
	}

	function ensurePopoverEl() {
		if ( popoverEl ) {
			return popoverEl;
		}
		popoverEl = el( 'div', { class: 'gadget-blame-popover', role: 'dialog', 'aria-label': 'Revision' } );
		if ( 'popover' in popoverEl ) {
			popoverEl.setAttribute( 'popover', 'auto' );
			// Light dismissal bypasses hidePopover, so the ring is cleared here.
			popoverEl.addEventListener( 'toggle', ( e ) => {
				if ( e.newState === 'closed' ) {
					setActive( false );
					popoverAnchor = null;
				}
			} );
		} else {
			document.addEventListener( 'click', ( e ) => {
				if ( popoverAnchor && !popoverEl.contains( e.target ) && !e.target.closest( '.gadget-blame-w' ) ) {
					hidePopover();
				}
			} );
			document.addEventListener( 'keydown', ( e ) => {
				if ( e.key === 'Escape' && popoverAnchor ) {
					hidePopover();
				}
			} );
		}
		// The anchor is inline text, so it moves with the page.
		window.addEventListener( 'scroll', place, true );
		window.addEventListener( 'resize', place );
		teleportTarget.appendChild( popoverEl );
		return popoverEl;
	}

	function card( rev ) {
		if ( !rev ) {
			return [ message( 'notice', [ 'Not written on this page — template or module output.' ] ) ];
		}
		const isIp = mw.util.isIPAddress ? mw.util.isIPAddress( rev.user ) : false;
		const who = rev.user ?
			link( mw.util.getUrl( ( isIp ? 'Special:Contributions/' : 'User:' ) + rev.user ), rev.user, 'gadget-blame__user' ) :
			el( 'span', { class: 'gadget-blame__meta', text: HIDDEN } );
		return [ el( 'div', { class: 'gadget-blame__card' }, [
			el( 'div', { class: 'gadget-blame__date', text: formatDate( rev.timestamp ) } ),
			el( 'div', null, [ who ] ),
			rev.comment ? el( 'div', { class: 'gadget-blame__summary', text: rev.comment } ) : null,
			el( 'div', { class: 'gadget-blame__links' }, [
				link( mw.util.getUrl( 'Special:Diff/' + rev.id ), 'Diff' ),
				link( mw.util.getUrl( 'Special:PermanentLink/' + rev.id ), 'Revision ' + rev.id )
			] )
		] ) ];
	}

	function showPopover( anchor, rev ) {
		const node = ensurePopoverEl();
		setActive( false );
		popoverAnchor = anchor;
		setBody( node, card( rev ) );
		if ( node.showPopover ) {
			if ( node.matches( ':popover-open' ) ) {
				node.hidePopover();
			}
			node.showPopover();
		} else {
			node.classList.add( 'gadget-blame-popover--open' );
		}
		setActive( true );
		place();
	}

	// Text is gathered per block so a word split across inline markup
	// ("<i>Title</i>'s") is tokenised whole rather than as three fragments.
	const BLOCKS = 'address, article, aside, blockquote, caption, dd, details, dialog, div, dl, dt, fieldset, figcaption, figure, footer, form, h1, h2, h3, h4, h5, h6, header, hgroup, li, main, nav, ol, p, pre, section, summary, table, tbody, td, tfoot, th, thead, tr, ul';

	// A word straddling an inline element has more than one text-node range.
	function renderedTokens( root ) {
		const walker = document.createTreeWalker( root, NodeFilter.SHOW_TEXT, {
			acceptNode: ( n ) => {
				const p = n.parentElement;
				return p && !p.closest( UNPAINTED ) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
			}
		} );
		const re = new RegExp( text.TOKEN_RE.source, text.TOKEN_RE.flags );
		const out = [];
		let block = null;
		let joined = '';
		let segments = [];

		function flush() {
			if ( !joined ) {
				return;
			}
			re.lastIndex = 0;
			let m;
			let seg = 0;
			while ( ( m = re.exec( joined ) ) ) {
				const norm = text.normaliseText( m[ 0 ] );
				if ( !norm ) {
					continue;
				}
				const from = m.index;
				const to = from + m[ 0 ].length;
				while ( seg < segments.length && segments[ seg ].end <= from ) {
					seg++;
				}
				const pieces = [];
				for ( let i = seg; i < segments.length && segments[ i ].start < to; i++ ) {
					const sgm = segments[ i ];
					pieces.push( {
						node: sgm.node,
						start: Math.max( from, sgm.start ) - sgm.start,
						end: Math.min( to, sgm.end ) - sgm.start
					} );
				}
				out.push( { pieces, norm } );
			}
			joined = '';
			segments = [];
		}

		let n;
		while ( ( n = walker.nextNode() ) ) {
			const owner = n.parentElement.closest( BLOCKS ) || root;
			if ( owner !== block ) {
				flush();
				block = owner;
			}
			segments.push( { node: n, start: joined.length, end: joined.length + n.nodeValue.length } );
			joined += n.nodeValue;
		}
		flush();
		return out;
	}

	// One replacement per text node; the original is kept for unpaint().
	function paint( tokens, classify ) {
		// A span cannot straddle text nodes, so a word split across inline markup
		// is painted once per node, each piece carrying the same origin.
		const byNode = new Map();
		tokens.forEach( ( t, k ) => {
			const c = classify( k );
			t.pieces.forEach( ( piece ) => {
				if ( !byNode.has( piece.node ) ) {
					byNode.set( piece.node, [] );
				}
				byNode.get( piece.node ).push( { start: piece.start, end: piece.end, c } );
			} );
		} );
		byNode.forEach( ( pieces, node ) => {
			const s = node.nodeValue;
			const frag = document.createDocumentFragment();
			const added = [];
			let pos = 0;
			let k = 0;
			while ( k < pieces.length ) {
				const c = pieces[ k ].c;
				const key = c ? c.rev : -1;
				const start = pieces[ k ].start;
				let end = pieces[ k ].end;
				let next = k + 1;
				while ( next < pieces.length ) {
					const cn = pieces[ next ].c;
					if ( ( cn ? cn.rev : -1 ) !== key ) {
						break;
					}
					end = pieces[ next ].end;
					next++;
				}
				if ( start > pos ) {
					added.push( frag.appendChild( document.createTextNode( s.slice( pos, start ) ) ) );
				}
				const span = el( 'span', {
					class: 'gadget-blame-w ' + ( c ? 'gadget-blame-a' + c.cls : 'gadget-blame-w--template' ),
					text: s.slice( start, end )
				} );
				if ( c ) {
					span.setAttribute( 'data-gadget-blame-revid', String( c.rev ) );
					// So attribution is not carried by colour alone.
					span.setAttribute( 'title', c.who );
				}
				added.push( frag.appendChild( span ) );
				pos = end;
				k = next;
			}
			if ( pos < s.length ) {
				added.push( frag.appendChild( document.createTextNode( s.slice( pos ) ) ) );
			}
			node.parentNode.replaceChild( frag, node );
			page.painted.push( { original: node, pieces: added } );
		} );
	}

	// Roving tabindex: thousands of tab stops would make the article unusable.
	// The runs deliberately carry no role either — one would make a screen reader
	// announce every phrase as a control instead of reading it as prose.
	function runs() {
		const root = contentRoot();
		return root ? Array.from( root.querySelectorAll( '.gadget-blame-w' ) ) : [];
	}

	function setTabStop( run ) {
		runs().forEach( ( r ) => r.setAttribute( 'tabindex', r === run ? '0' : '-1' ) );
	}

	function moveTabStop( from, delta ) {
		const all = runs();
		const i = all.indexOf( from );
		const next = all[ Math.min( all.length - 1, Math.max( 0, ( i < 0 ? 0 : i ) + delta ) ) ];
		if ( next ) {
			setTabStop( next );
			next.focus();
			next.scrollIntoView( { block: 'nearest' } );
		}
		return next;
	}

	function unpaint() {
		page.painted.forEach( ( p ) => {
			const first = p.pieces[ 0 ];
			if ( first && first.parentNode ) {
				first.parentNode.insertBefore( p.original, first );
			}
			p.pieces.forEach( ( n ) => n.parentNode && n.parentNode.removeChild( n ) );
		} );
		page.painted = [];
	}

	function closeLegend() {
		if ( page.legend ) {
			page.legend.remove();
			page.legend = null;
		}
	}

	function turnOff() {
		page.token++;
		page.on = false;
		unpaint();
		closeLegend();
		page.revById = null;
		hidePopover();
	}

	function openLegend() {
		closeLegend();
		const body = el( 'div', { class: 'gadget-blame__body' } );
		const off = iconButton( 'Turn off', ICON_CLOSE );
		off.addEventListener( 'click', turnOff );
		page.legend = el( 'div', { class: 'gadget-blame-legend', role: 'region', 'aria-label': 'Blame legend' }, [
			el( 'div', { class: 'gadget-blame__header' }, [
				el( 'span', { class: 'gadget-blame__title', text: 'Blame' } ),
				off
			] ),
			body
		] );
		teleportTarget.appendChild( page.legend );
		return body;
	}

	function pct( n, total ) {
		if ( !total || !n ) {
			return '0%';
		}
		const p = Math.round( 100 * n / total );
		return p === 0 ? '<1%' : p + '%';
	}

	function legendRow( swatchClass, label, share ) {
		const labelNode = typeof label === 'string' ? el( 'span', { text: label } ) : label;
		labelNode.classList.add( 'gadget-blame__label' );
		return el( 'div', { class: 'gadget-blame__row' }, [
			el( 'span', { class: 'gadget-blame-swatch ' + swatchClass } ),
			labelNode,
			el( 'span', { class: 'gadget-blame__meta', text: share } )
		] );
	}

	function plural( n, word ) {
		return n + ' ' + word + ( n === 1 ? '' : 's' );
	}

	function renderLegend( body, stats ) {
		const rows = stats.authors.slice( 0, PALETTE_SIZE ).map( ( pair, idx ) => legendRow(
			'gadget-blame-a' + idx,
			userLink( pair[ 0 ] === HIDDEN ? '' : pair[ 0 ] ),
			pct( pair[ 1 ], stats.total )
		) );
		const rest = stats.authors.slice( PALETTE_SIZE );
		if ( rest.length ) {
			const n = rest.reduce( ( sum, pair ) => sum + pair[ 1 ], 0 );
			rows.push( legendRow( 'gadget-blame-ax', plural( rest.length, 'other editor' ), pct( n, stats.total ) ) );
		}
		if ( stats.template ) {
			rows.push( legendRow( 'gadget-blame-w--template', 'Template output', pct( stats.template, stats.total ) ) );
		}
		const notes = [ plural( stats.revisions, 'revision' ) + ' blamed' ];
		if ( stats.reused ) {
			notes.push( plural( stats.reused, 'revision' ) + ' restored an earlier version' );
		}
		if ( stats.capped ) {
			notes.push( plural( stats.capped, 'revision' ) + ' changed too much to trace word by word' );
		}
		if ( stats.gaps ) {
			notes.push( 'text older than this history, or from a hidden revision, is credited to the oldest revision that shows it' );
		}
		if ( stats.alignCapped ) {
			notes.push( 'this page and its source differ too much to line up, so nothing could be attributed' );
		}
		rows.push( el( 'div', {
			class: 'gadget-blame__footer',
			text: notes.join( '. ' ) + '. Click a word for its revision, or tab into the text and use the arrow keys.'
		} ) );
		setBody( body, rows );
	}

	// One revision at a time: only the previous token stream is ever needed, and
	// holding every stream at once runs to hundreds of megabytes.
	async function buildOrigins( revs, body, token ) {
		const pageName = config.wgPageName.replace( /_/g, ' ' );
		const blamer = text.makeBlamer(
			text.duplicateSha1s( revs.map( ( r ) => r.sha1 ) ),
			MAX_D_REVISION
		);
		const intern = text.makeInterner();
		let reused = 0;
		let slice = performance.now();
		for ( let i = 0; i < revs.length; i++ ) {
			const r = revs[ i ];
			if ( blamer.reuse( r.sha1 ) ) {
				reused++;
			} else {
				blamer.push( intern( text.tokenize( text.wikitextToText( r.text, { pageName } ) ) ), i, r.sha1 );
			}
			if ( performance.now() - slice > SLICE_MS ) {
				loading( body, 'Blaming ' + ( i + 1 ) + ' of ' + revs.length + ' revisions…' );
				await tick();
				if ( token !== page.token ) {
					return null;
				}
				slice = performance.now();
			}
		}
		return { intern, origins: blamer.origins, stream: blamer.stream, capped: blamer.capped, reused };
	}

	async function blamePage() {
		if ( page.on ) {
			turnOff();
			return;
		}
		const root = contentRoot();
		if ( !root ) {
			return;
		}
		page.on = true;
		const token = ++page.token;
		const body = openLegend();
		loading( body, 'Fetching history…' );
		try {
			const all = await loadHistory();
			if ( token !== page.token ) {
				return;
			}
			const upTo = config.wgRevisionId || config.wgCurRevisionId || Infinity;
			const visible = all.filter( ( r ) => r.id <= upTo );
			const revs = visible.filter( ( r ) => r.text !== null );
			if ( !revs.length ) {
				setBody( body, [ message( 'warning', [ 'No readable revisions to blame on this page.' ] ) ] );
				return;
			}
			// Text this history cannot account for: revisions hidden inside it, or a
			// history not starting at the page's creation.
			const gaps = ( visible.length - revs.length ) + ( revs[ 0 ].parentid > 0 ? 1 : 0 );
			const built = await buildOrigins( revs, body, token );
			if ( !built ) {
				return;
			}
			const toks = renderedTokens( root );
			const alignStats = {};
			const norms = toks.map( ( t ) => t.norm );
			const map = text.dropPunctuationOnlyRuns(
				text.diffMap( built.stream, built.intern( norms ), MAX_D_ALIGN, alignStats ),
				norms
			);
			const counts = new Map();
			let aligned = 0;
			for ( let k = 0; k < toks.length; k++ ) {
				if ( map[ k ] >= 0 ) {
					aligned++;
					const u = revs[ built.origins[ map[ k ] ] ].user || HIDDEN;
					counts.set( u, ( counts.get( u ) || 0 ) + 1 );
				}
			}
			const authors = Array.from( counts.entries() ).sort( ( a, b ) => b[ 1 ] - a[ 1 ] );
			const cls = new Map();
			authors.forEach( ( pair, idx ) => cls.set( pair[ 0 ], idx < PALETTE_SIZE ? String( idx ) : 'x' ) );
			page.revById = new Map( revs.map( ( r ) => [ r.id, r ] ) );
			paint( toks, ( k ) => {
				const w = map[ k ];
				if ( w < 0 ) {
					return null;
				}
				const r = revs[ built.origins[ w ] ];
				return { cls: cls.get( r.user || HIDDEN ), rev: r.id, who: r.user || HIDDEN };
			} );
			setTabStop( toks.length ? contentRoot().querySelector( '.gadget-blame-w' ) : null );
			renderLegend( body, {
				authors,
				total: toks.length,
				template: toks.length - aligned,
				revisions: revs.length,
				reused: built.reused,
				capped: built.capped,
				alignCapped: !!alignStats.capped,
				gaps
			} );
			// Tens of megabytes on a long history; only popover metadata is kept.
			revs.forEach( ( r ) => {
				r.text = null;
			} );
			historyPromise = null;
		} catch ( err ) {
			if ( token === page.token ) {
				renderError( body, err );
			}
		}
	}

	function openRun( w ) {
		setTabStop( w );
		const id = w.getAttribute( 'data-gadget-blame-revid' );
		showPopover( w, id === null ? null : page.revById.get( Number( id ) ) );
	}

	// While blame is on, a run inside a link opens its revision instead of
	// following the link.
	document.addEventListener( 'click', ( e ) => {
		const w = page.on && e.target.closest && e.target.closest( '.gadget-blame-w' );
		if ( !w ) {
			return;
		}
		if ( w.closest( 'a' ) ) {
			e.preventDefault();
		}
		openRun( w );
	} );

	document.addEventListener( 'keydown', ( e ) => {
		const w = page.on && e.target.closest && e.target.closest( '.gadget-blame-w' );
		if ( !w || e.altKey || e.ctrlKey || e.metaKey ) {
			return;
		}
		if ( e.key === 'ArrowRight' || e.key === 'ArrowDown' ) {
			e.preventDefault();
			moveTabStop( w, 1 );
		} else if ( e.key === 'ArrowLeft' || e.key === 'ArrowUp' ) {
			e.preventDefault();
			moveTabStop( w, -1 );
		} else if ( e.key === 'Enter' || e.key === ' ' ) {
			e.preventDefault();
			openRun( w );
		}
	} );

	const item = mw.util.addPortletLink( 'p-tb', '#', 'Blame this page', 'gadget-blame-page', 'Colour every word by the editor who last changed it' );
	if ( item ) {
		item.addEventListener( 'click', ( e ) => {
			e.preventDefault();
			blamePage();
		} );
	}
}() );