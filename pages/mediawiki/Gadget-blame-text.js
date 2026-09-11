/*
 * Gadget: Blame — git blame for articles. Colours every word by the editor who
 * last changed it; words a template or module produced are hatched instead.
 *
 * [[MediaWiki:Gadget-blame.js]]
 * [[MediaWiki:Gadget-blame-text.js]]
 * [[MediaWiki:Gadget-blame.css]]
 *
 * The normaliser only has to make words line up, not reproduce the parser. The
 * two failure directions are not symmetric: over-inclusion is harmless, because
 * a word must also appear in the rendered article to be painted, while
 * under-inclusion silently hatches an article word as template output.
 */
( function () {
	'use strict';

	// <ref> is deliberately NOT here: moveRefs relocates its body to the reference
	// list instead, so the text stays attributable.
	const DROP_TAGS = 'references|gallery|imagemap|syntaxhighlight|source|pre|math|score|templatedata|timeline|graph|mapframe|maplink|inputbox|categorytree';
	// <nowiki> is handled separately: its body must survive the markup rules
	// literally, not merely lose its tags.
	const UNWRAP_TAGS = 'noinclude|includeonly|onlyinclude';

	const NAMED_ENTITIES = {
		// Space entities decode to ASCII space, not their real code point: the
		// deploy transport rewrites non-ASCII whitespace in source.
		nbsp: ' ', ensp: ' ', emsp: ' ', thinsp: ' ',
		zwnj: String.fromCharCode( 0x200C ), zwj: String.fromCharCode( 0x200D ), shy: String.fromCharCode( 0xAD ),
		lt: '<', gt: '>', quot: '"', apos: '\'',
		ndash: '–', mdash: '—', hellip: '…',
		laquo: '«', raquo: '»', ldquo: '“', rdquo: '”',
		lsquo: '‘', rsquo: '’', bull: '•', middot: '·',
		deg: '°', times: '×', minus: '−', plusmn: '±',
		micro: 'µ', copy: '©', reg: '®', trade: '™',
		frac12: '½', frac14: '¼', frac34: '¾'
	};

	// String.fromCodePoint THROWS above U+10FFFF and on surrogates, which would
	// abort the whole run over one malformed entity.
	function codePoint( m, code ) {
		return code <= 0x10FFFF && ( code < 0xD800 || code > 0xDFFF ) ? String.fromCodePoint( code ) : m;
	}

	function decodeEntities( s ) {
		return s
			.replace( /&#(\d+);/g, ( m, d ) => codePoint( m, Number( d ) ) )
			.replace( /&#x([0-9a-f]+);/gi, ( m, h ) => codePoint( m, parseInt( h, 16 ) ) )
			.replace( /&([a-z][a-z0-9]*);/gi, ( m, name ) => {
				const v = NAMED_ENTITIES[ name.toLowerCase() ];
				return v === undefined ? m : v;
			} )
			// Last, so "&amp;lt;" decodes to the literal "&lt;" rather than "<".
			.replace( /&amp;/g, '&' );
	}

	// Applied to BOTH sides of the comparison. Case folds because {{lc:}}/{{uc:}}
	// and CSS text-transform would otherwise split a match. Built from code points
	// because the deploy transport decodes \u escapes, so an invisible character
	// written literally would reach the wiki as raw bytes.
	// Soft hyphen, zero-width space/joiners/marks, word joiner, BOM.
	const ZERO_WIDTH = new RegExp( '[' + String.fromCharCode( 0xAD, 0x200B ) + '-' + String.fromCharCode( 0x200F, 0x2060, 0xFEFF ) + ']', 'g' );
	// NFC is a no-op on printable ASCII, and the test is far cheaper than it.
	const NON_ASCII = /[^\x20-\x7E\t\n\r]/;
	function normaliseText( s ) {
		return ( NON_ASCII.test( s ) ? s.normalize( 'NFC' ) : s )
			.replace( ZERO_WIDTH, '' )
			// \s already covers nbsp, U+2028/9 and the rest.
			.replace( /\s+/g, ' ' )
			.trim()
			.toLowerCase();
	}

	// A <ref> body sits inline in the wikitext but renders at the foot of the page,
	// and the alignment is order-sensitive, so the bodies move to the end. Order is
	// Cite's: first APPEARANCE of the name, definition or reuse, whichever comes
	// first. Ordering by definition would shift an entry whenever an editor
	// converts one to a reuse, dragging the alignment with it.
	const REF_RE = /<ref(\s[^>]*?)?\s*\/>|<ref(\s[^>]*?)?>([\s\S]*?)<\/ref\s*>/gi;
	const REF_NAME_RE = /name\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s/>]+))/i;
	function moveRefs( s ) {
		const order = [];
		const byName = new Map();
		const stripped = s.replace( REF_RE, ( m, selfAttrs, openAttrs, body ) => {
			const nm = REF_NAME_RE.exec( ( body === undefined ? selfAttrs : openAttrs ) || '' );
			const name = nm ? ( nm[ 1 ] || nm[ 2 ] || nm[ 3 ] ) : null;
			if ( !name ) {
				if ( body !== undefined ) {
					order.push( { body } );
				}
				return ' ';
			}
			let entry = byName.get( name );
			if ( !entry ) {
				entry = { body: '' };
				byName.set( name, entry );
				order.push( entry );
			}
			if ( body !== undefined && !entry.body ) {
				entry.body = body;
			}
			return ' ';
		} );
		const bodies = order.map( ( e ) => e.body ).filter( Boolean );
		return bodies.length ? stripped + '\n' + bodies.join( '\n' ) : stripped;
	}

	// Character codes, not substr: this runs over every character of every
	// revision, and substr allocates a string per position.
	function splitTopLevel( s ) {
		const parts = [];
		let depth = 0;
		let start = 0;
		for ( let i = 0; i < s.length; i++ ) {
			const c = s.charCodeAt( i );
			const d = s.charCodeAt( i + 1 );
			if ( ( c === 123 && d === 123 ) || ( c === 91 && d === 91 ) ) {
				depth++;
				i++;
			} else if ( ( c === 125 && d === 125 ) || ( c === 93 && d === 93 ) ) {
				depth = Math.max( 0, depth - 1 );
				i++;
			} else if ( c === 124 && depth === 0 ) {
				parts.push( s.slice( start, i ) );
				start = i + 1;
			}
		}
		parts.push( s.slice( start ) );
		return parts;
	}

	// Parameter VALUES are article-authored prose (infobox fields, {{Note|...}},
	// {{quote|...}}) and must stay matchable; names and keys never render. Every
	// parser-function branch is kept, since over-inclusion is safe.
	function stripTemplates( s ) {
		let out = '';
		let i = 0;
		while ( i < s.length ) {
			if ( s.startsWith( '{{', i ) ) {
				let depth = 0;
				let j = i;
				let end = -1;
				while ( j < s.length ) {
					if ( s.startsWith( '{{', j ) ) {
						depth++;
						j += 2;
					} else if ( s.startsWith( '}}', j ) ) {
						depth--;
						j += 2;
						if ( depth === 0 ) {
							end = j;
							break;
						}
					} else {
						j++;
					}
				}
				if ( end === -1 ) {
					out += s.slice( i );
					break;
				}
				const inner = s.slice( i + 2, end - 2 );
				const params = splitTopLevel( inner ).slice( 1 );
				const values = params.map( ( p ) => {
					const m = /^\s*[^=|{}[\]<>]{1,80}?\s*=([\s\S]*)$/.exec( p );
					return stripTemplates( m ? m[ 1 ] : p );
				} );
				out += ' ' + values.join( ' ' ) + ' ';
				i = end;
			} else {
				// Appending character by character dominated the profile.
				const next = s.indexOf( '{{', i );
				if ( next === -1 ) {
					out += s.slice( i );
					break;
				}
				out += s.slice( i, next );
				i = next;
			}
		}
		return out;
	}

	// Balanced removal, because captions nest links. A LEADING COLON makes it a
	// link to the page rather than a file or category, so it is left alone.
	function stripFileLinks( s ) {
		const re = /\[\[(?:file|image|media|category):/gi;
		let out = '';
		let last = 0;
		let m;
		while ( ( m = re.exec( s ) ) !== null ) {
			let depth = 0;
			let j = m.index;
			let end = -1;
			while ( j < s.length ) {
				if ( s.startsWith( '[[', j ) ) {
					depth++;
					j += 2;
				} else if ( s.startsWith( ']]', j ) ) {
					depth--;
					j += 2;
					if ( depth === 0 ) {
						end = j;
						break;
					}
				} else {
					j++;
				}
			}
			if ( end === -1 ) {
				break;
			}
			out += s.slice( last, m.index ) + ' ';
			last = end;
			re.lastIndex = end;
		}
		return out + s.slice( last );
	}

	// Must run AFTER stripTemplates, or "| key = value" parameters read as cells.
	function stripTables( s ) {
		// Most revisions have no table markup and the split and rejoin is costly.
		if ( !/^[|!]|^\{\|/m.test( s ) ) {
			return s;
		}
		return s.split( '\n' ).map( ( line ) => {
			const t = line.trim();
			if ( /^\{\|/.test( t ) || t === '|}' || /^\|-/.test( t ) ) {
				return '';
			}
			if ( /^\|\+/.test( t ) ) {
				return t.slice( 2 );
			}
			if ( /^[|!]/.test( t ) ) {
				return t.slice( 1 ).split( /\|\||!!/ ).map( ( cell ) => {
					// A single pipe whose left side looks like attributes is a cell
					// prefix, not content.
					const k = cell.indexOf( '|' );
					if ( k !== -1 && /^\s*[a-z-]+\s*=/i.test( cell ) ) {
						return cell.slice( k + 1 );
					}
					return cell;
				} ).join( ' ' );
			}
			return line;
		} ).join( '\n' );
	}

	/**
	 * Wikitext → approximate rendered prose, normalised.
	 *
	 * @param {string} wt
	 * @param {{pageName?: string}} [opts] pageName substitutes {{PAGENAME}} family
	 * @return {string}
	 */
	function wikitextToText( wt, opts ) {
		const pageName = ( opts && opts.pageName ) || '';
		let s = wt;
		s = s.replace( /<!--[\s\S]*?-->/g, '' );
		// Restored before entity decoding, which MediaWiki still applies inside
		// nowiki. A bare <nowiki/> becomes an EMPTY PLACEHOLDER rather than
		// vanishing: editors use it to split apostrophe runs (''Ship''<nowiki/>'s),
		// and removing it outright would re-fuse them into bold markup.
		const nowikis = [];
		const NUL = String.fromCharCode( 0 );
		s = s.replace( /<nowiki\s*\/>|<nowiki>([\s\S]*?)<\/nowiki>/gi, ( m, body ) => {
			nowikis.push( body || '' );
			return NUL + ( nowikis.length - 1 ) + NUL;
		} );
		s = moveRefs( s );
		s = s.replace( new RegExp( '<(' + DROP_TAGS + ')\\b[^>]*/>', 'gi' ), ' ' );
		s = s.replace( new RegExp( '<(' + DROP_TAGS + ')\\b[^>]*>[\\s\\S]*?</\\1\\s*>', 'gi' ), ' ' );
		s = s.replace( /<templatestyles\b[^>]*\/?>/gi, '' );
		s = s.replace( new RegExp( '</?(' + UNWRAP_TAGS + ')\\b[^>]*>', 'gi' ), '' );
		s = s.replace( /__[A-Z]+__/g, '' );
		if ( pageName ) {
			s = s.replace( /\{\{\s*(?:FULL)?PAGENAME\s*\}\}/g, pageName );
		}
		s = stripTemplates( s );
		s = stripTables( s );
		s = stripFileLinks( s );
		// Link trails ([[Page]]s) survive as the letters after the brackets.
		s = s.replace( /\[\[:?(?:[^|\]]*\|)?([^\]]*)\]\]/g, '$1' );
		// A bare [url] renders as a numbered marker, so it contributes no words.
		s = s.replace( /\[(?:https?:|ftp:|\/\/)[^\s\]]+\s+([^\]]*)\]/gi, '$1' );
		s = s.replace( /\[(?:https?:|ftp:|\/\/)[^\s\]]+\]/gi, ' ' );
		// doQuotes: 2, 3 and 5 are pure markup, but 4 is a literal apostrophe then
		// bold ('''Ship''''s -> Ship's), and beyond 5 the surplus is literal.
		s = s.replace( /'{2,}/g, ( run ) => {
			const n = run.length;
			if ( n === 4 ) {
				return '\'';
			}
			return n > 5 ? '\''.repeat( n - 5 ) : '';
		} );
		s = s.replace( /^(={1,6})\s*(.*?)\s*=+\s*$/gm, '$2' );
		s = s.replace( /^[*#:;]+\s*/gm, '' );
		s = s.replace( /^-{4,}\s*$/gm, '' );
		s = s.replace( /<br\s*\/?>/gi, ' ' );
		s = s.replace( /<\/?[a-z][^>]*>/gi, '' );
		s = s.replace( new RegExp( NUL + '(\\d+)' + NUL, 'g' ), ( m, n ) => nowikis[ Number( n ) ] );
		s = decodeEntities( s );
		return normaliseText( s );
	}

	// Punctuation is its own token so a comma edit recolours the comma, not the
	// word either side of it.
	const TOKEN_RE = /[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*|[^\s\p{L}\p{N}]/gu;

	function tokenize( text ) {
		return text.match( TOKEN_RE ) || [];
	}

	// One interner must be shared by every sequence that will be diffed together.
	function makeInterner() {
		const ids = new Map();
		return function ( tokens ) {
			const out = new Int32Array( tokens.length );
			for ( let i = 0; i < tokens.length; i++ ) {
				let id = ids.get( tokens[ i ] );
				if ( id === undefined ) {
					id = ids.size;
					ids.set( tokens[ i ], id );
				}
				out[ i ] = id;
			}
			return out;
		};
	}

	/**
	 * Myers O(ND) diff over two integer sequences. Returns, for every position
	 * in `b`, the matching position in `a`, or -1 where b's token has no
	 * counterpart (inserted). Common prefix and suffix are matched first. The
	 * edit distance is capped: past `maxD` the unmatched middle is left at -1,
	 * i.e. treated as a full rewrite, which bounds time to O((N+M)·D) and the
	 * backtrack trace to O(D²) ints.
	 *
	 * @param {Int32Array|number[]} a
	 * @param {Int32Array|number[]} b
	 * @param {number} maxD
	 * @param {Object} [stats] Receives `capped: true` when the cap was hit, so a
	 *   caller can tell "nothing in common" from "gave up looking".
	 * @return {Int32Array}
	 */
	function diffMap( a, b, maxD, stats ) {
		const n = a.length;
		const m = b.length;
		const map = new Int32Array( m ).fill( -1 );
		let pre = 0;
		while ( pre < n && pre < m && a[ pre ] === b[ pre ] ) {
			map[ pre ] = pre;
			pre++;
		}
		let suf = 0;
		while ( suf < n - pre && suf < m - pre && a[ n - 1 - suf ] === b[ m - 1 - suf ] ) {
			map[ m - 1 - suf ] = n - 1 - suf;
			suf++;
		}
		const N = n - pre - suf;
		const M = m - pre - suf;
		if ( N === 0 || M === 0 ) {
			return map;
		}
		const cap = Math.min( N + M, maxD );
		const offset = cap + 1;
		const V = new Int32Array( 2 * offset + 1 );
		V[ offset + 1 ] = 0;
		// trace[d] holds V for k in [-d-1, d+1] as it stood before step d.
		const trace = [];
		let dFound = -1;
		for ( let d = 0; d <= cap && dFound < 0; d++ ) {
			trace.push( V.slice( offset - d - 1, offset + d + 2 ) );
			for ( let k = -d; k <= d; k += 2 ) {
				let x;
				if ( k === -d || ( k !== d && V[ offset + k - 1 ] < V[ offset + k + 1 ] ) ) {
					x = V[ offset + k + 1 ];
				} else {
					x = V[ offset + k - 1 ] + 1;
				}
				let y = x - k;
				while ( x < N && y < M && a[ pre + x ] === b[ pre + y ] ) {
					x++;
					y++;
				}
				V[ offset + k ] = x;
				if ( x >= N && y >= M ) {
					dFound = d;
					break;
				}
			}
		}
		if ( dFound < 0 ) {
			if ( stats ) {
				stats.capped = true;
			}
			return map;
		}
		let x = N;
		let y = M;
		for ( let d = dFound; d > 0; d-- ) {
			const Vd = trace[ d ];
			const base = d + 1;
			const k = x - y;
			const prevK = ( k === -d || ( k !== d && Vd[ k - 1 + base ] < Vd[ k + 1 + base ] ) ) ? k + 1 : k - 1;
			const prevX = Vd[ prevK + base ];
			const prevY = prevX - prevK;
			const midX = prevK === k + 1 ? prevX : prevX + 1;
			const midY = midX - k;
			while ( x > midX && y > midY ) {
				x--;
				y--;
				map[ pre + y ] = pre + x;
			}
			x = prevX;
			y = prevY;
		}
		while ( x > 0 && y > 0 ) {
			x--;
			y--;
			map[ pre + y ] = pre + x;
		}
		return map;
	}

	// An isolated ".", "/" or "-" lines up with some punctuation in the source by
	// coincidence, and the diff takes the match because it lowers the edit
	// distance. Crediting a named editor with it is noise. Runs holding at least
	// one real word keep their punctuation.
	const WORD_CHAR = /[\p{L}\p{N}]/u;
	function dropPunctuationOnlyRuns( map, tokens ) {
		let i = 0;
		while ( i < map.length ) {
			if ( map[ i ] < 0 ) {
				i++;
				continue;
			}
			let j = i;
			let hasWord = false;
			while ( j < map.length && map[ j ] >= 0 ) {
				if ( WORD_CHAR.test( tokens[ j ] ) ) {
					hasWord = true;
				}
				j++;
			}
			if ( !hasWord ) {
				for ( let k = i; k < j; k++ ) {
					map[ k ] = -1;
				}
			}
			i = j;
		}
		return map;
	}

	// A repeated sha1 means the page was restored to a state it already held, so
	// the restorer inherits that state's origins rather than being credited with
	// the text. Covers a rollback of any length, not just an adjacent A,B,A.
	function duplicateSha1s( sha1s ) {
		const seen = new Set();
		const dup = new Set();
		sha1s.forEach( ( h ) => {
			if ( !h ) {
				return;
			}
			if ( seen.has( h ) ) {
				dup.add( h );
			} else {
				seen.add( h );
			}
		} );
		return dup;
	}

	function blameStep( prevOrigins, prevStream, stream, index, maxD, stats ) {
		const map = diffMap( prevStream, stream, maxD, stats );
		const origins = new Int32Array( stream.length );
		for ( let j = 0; j < stream.length; j++ ) {
			origins[ j ] = map[ j ] >= 0 ? prevOrigins[ map[ j ] ] : index;
		}
		return origins;
	}

	// Fed oldest revision first. Only the previous stream is retained, so peak
	// memory is two revisions however long the history.
	//
	// Call reuse() FIRST: when it returns true the revision restores a state the
	// page already held, and the caller can skip normalising, tokenising and
	// diffing it entirely.
	function makeBlamer( duplicates, maxD ) {
		const memo = new Map();
		let prevStream = null;
		let origins = null;
		let capped = 0;
		return {
			reuse( sha1 ) {
				const hit = sha1 ? memo.get( sha1 ) : null;
				if ( !hit ) {
					return false;
				}
				prevStream = hit.stream;
				origins = hit.origins;
				return true;
			},
			push( stream, index, sha1 ) {
				if ( origins === null ) {
					origins = new Int32Array( stream.length ).fill( index );
				} else {
					const stats = {};
					origins = blameStep( origins, prevStream, stream, index, maxD, stats );
					if ( stats.capped ) {
						capped++;
					}
				}
				prevStream = stream;
				if ( sha1 && duplicates.has( sha1 ) ) {
					memo.set( sha1, { stream, origins } );
				}
			},
			get origins() {
				return origins;
			},
			get stream() {
				return prevStream;
			},
			// Everything unmatched was credited to the newer revision, so the caller
			// must report this count rather than present it as certain.
			get capped() {
				return capped;
			}
		};
	}

	module.exports = {
		decodeEntities,
		normaliseText,
		wikitextToText,
		TOKEN_RE,
		tokenize,
		makeInterner,
		diffMap,
		dropPunctuationOnlyRuns,
		duplicateSha1s,
		blameStep,
		makeBlamer
	};
}() );