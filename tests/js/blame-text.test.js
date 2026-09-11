'use strict';

const { test } = require( 'node:test' );
const assert = require( 'node:assert/strict' );
const T = require( '../../pages/mediawiki/Gadget-blame-text.js' );

test( 'decodeEntities: numeric, named, and &amp; last', () => {
	// &#160; is a real non-breaking space; only normaliseText folds it to U+0020.
	assert.equal( T.decodeEntities( 'a&#160;b' ), 'a' + String.fromCharCode( 0xA0 ) + 'b' );
	assert.equal( T.decodeEntities( '&#x2013;' ), '–' );
	assert.equal( T.decodeEntities( 'x&ndash;y &hellip;' ), 'x–y …' );
	assert.equal( T.decodeEntities( '&amp;lt;' ), '&lt;' );
	assert.equal( T.decodeEntities( '&unknownentity;' ), '&unknownentity;' );
} );

test( 'decodeEntities: an out-of-range code point is left as written, not thrown', () => {
	// String.fromCodePoint would throw here and abort the whole blame run.
	assert.equal( T.decodeEntities( 'a &#xFFFFFFFF; b' ), 'a &#xFFFFFFFF; b' );
	assert.equal( T.decodeEntities( 'a &#99999999; b' ), 'a &#99999999; b' );
	assert.equal( T.decodeEntities( 'lone &#xD800; surrogate' ), 'lone &#xD800; surrogate' );
	assert.equal( T.decodeEntities( 'ok &#x1F600; ok' ), 'ok 😀 ok' );
} );

test( 'normaliseText: unicode spaces, zero-width chars, case, collapse', () => {
	const SHY = String.fromCharCode( 0xAD );
	const ZWSP = String.fromCharCode( 0x200B );
	const NBSP = String.fromCharCode( 0xA0 );
	assert.equal( T.normaliseText( 'A B C\t\nD' ), 'a b c d' );
	assert.equal( T.normaliseText( 'soft' + SHY + 'hyphen zero' + ZWSP + 'width' ), 'softhyphen zerowidth' );
	assert.equal( T.normaliseText( 'a' + NBSP + 'b' ), 'a b' );
	assert.equal( T.normaliseText( '  Many   spaces  ' ), 'many spaces' );
	assert.equal( T.normaliseText( 'café' ), 'café' );
} );

test( 'normaliseText: the ASCII fast path still composes decomposed input', () => {
	// normaliseText skips NFC when the string is printable ASCII. A combining
	// sequence must still compose, or the two sides of a comparison diverge.
	const NFD = 'cafe' + String.fromCharCode( 0x301 );
	assert.equal( NFD.length, 5 );
	assert.equal( T.normaliseText( NFD ), 'caf\u00e9'.normalize( 'NFC' ) );
	assert.equal( T.normaliseText( NFD ).length, 4 );
	assert.equal( T.normaliseText( 'plain ascii' ), 'plain ascii' );
} );

test( 'wikitextToText: pages without table markup take the skip path unchanged', () => {
	// stripTables returns early when no line starts with table markup.
	assert.equal( T.wikitextToText( 'Just prose.\nA second line | with a pipe.' ), 'just prose. a second line | with a pipe.' );
	assert.equal( T.wikitextToText( '{| class="wikitable"\n! H\n|-\n| c\n|}' ), 'h c' );
	// A line that merely begins with "!" is not a table, and must survive.
	assert.equal( T.wikitextToText( 'Prose.\n! not a header' ), 'prose. not a header' );
} );

test( 'wikitextToText: apostrophe runs follow doQuotes (4 = literal + bold)', () => {
	assert.equal( T.wikitextToText( "'''Squadron 42''''s soundtrack" ), 'squadron 42\'s soundtrack' );
	assert.equal( T.wikitextToText( "'''''both''''' and ''''''six" ), 'both and \'six' );
	// <nowiki/> is the idiom for keeping a possessive out of the italic run.
	assert.equal( T.wikitextToText( "''Squadron 42''<nowiki/>'s soundtrack" ), 'squadron 42\'s soundtrack' );
} );

test( 'wikitextToText: inline formatting and links', () => {
	assert.equal( T.wikitextToText( "The '''Aurora MR''' is ''fast''." ), 'the aurora mr is fast.' );
	assert.equal( T.wikitextToText( 'Built by [[Roberts Space Industries|RSI]].' ), 'built by rsi.' );
	assert.equal( T.wikitextToText( 'Two [[M50]]s and [[350r]]s.' ), 'two m50s and 350rs.' );
	assert.equal( T.wikitextToText( 'Part of the [[:Category:Aurora Mk I|Aurora MK I series]].' ), 'part of the aurora mk i series.' );
	assert.equal( T.wikitextToText( 'See [https://example.com the site] and [https://example.com].' ), 'see the site and .' );
} );

test( 'wikitextToText: file links removed with nested captions, categories dropped', () => {
	assert.equal(
		T.wikitextToText( '[[File:Aurora.png|thumb|The [[Aurora MR|Aurora]] in flight]] Body text. [[Category:Ships]]' ),
		'body text.'
	);
} );

test( 'wikitextToText: template parameter values survive, names and keys do not', () => {
	assert.equal(
		T.wikitextToText( "{{Note|'''Note:''' The '''Aurora Mk I''' is ceasing production.}}" ),
		'note: the aurora mk i is ceasing production.'
	);
	assert.equal(
		T.wikitextToText( '{{Vehicle\n| uuid = a6e1bb18\n| name = Aurora Mk I MR\n| role = \n}}' ),
		'a6e1bb18 aurora mk i mr'
	);
	assert.equal(
		T.wikitextToText( '{{List item\n|Cargo\n|The Marque has 3 SCU of cargo.<ref name="AuroraMR_Store"/>\n}}' ),
		'cargo the marque has 3 scu of cargo.'
	);
	// Nested templates inside a parameter.
	assert.equal( T.wikitextToText( '{{Outer|Text {{Inner|inside}} after}}' ), 'text inside after' );
	// Unbalanced braces are emitted literally rather than swallowing the page.
	assert.equal( T.wikitextToText( 'Broken {{Template text' ), 'broken {{template text' );
} );

test( 'wikitextToText: refs, comments, magic words, html tags', () => {
	// A <ref> body renders at the foot of the page, so it moves to the end.
	assert.equal( T.wikitextToText( 'Body.<ref>Cited source</ref> More.<ref name="x"/>' ), 'body. more. cited source' );
	assert.equal( T.wikitextToText( 'Keep <!-- hidden note --> this __NOTOC__ text' ), 'keep this text' );
	assert.equal( T.wikitextToText( 'A<br/>B <span style="color:red">red</span> <small>small</small>' ), 'a b red small' );
	assert.equal( T.wikitextToText( '<nowiki>[[not a link]]</nowiki>' ), '[[not a link]]' );
	assert.equal( T.wikitextToText( 'x &nbsp; y &amp; z' ), 'x y & z' );
} );

test( 'wikitextToText: reference bodies move to the end in Cite\'s order', () => {
	// First appearance wins, and a named ref is emitted once however often reused.
	assert.equal(
		T.wikitextToText( 'A<ref name="a">First</ref> B<ref name="a"/> C<ref>Second</ref>' ),
		'a b c first second'
	);
	// Order follows first appearance, not definition order in the markup.
	assert.equal(
		T.wikitextToText( 'X<ref>Alpha</ref> Y<ref>Beta</ref>' ),
		'x y alpha beta'
	);
	// Cite lists a named ref where the NAME first appears, even if the body is
	// defined further down; ordering by definition would move it.
	assert.equal(
		T.wikitextToText( 'A<ref name="z"/> B<ref>Anon</ref> C<ref name="z">Zed</ref>' ),
		'a b c zed anon'
	);
	// A reuse-only marker contributes nothing of its own.
	assert.equal( T.wikitextToText( 'Q<ref name="z"/>' ), 'q' );
	// Templates inside a ref body are stripped like anywhere else.
	assert.equal(
		T.wikitextToText( 'X<ref>{{Cite web|title=Deep Space}}</ref>' ),
		'x deep space'
	);
	// Single quotes and unquoted names are both valid Cite syntax.
	assert.equal( T.wikitextToText( "A<ref name='n'>Body</ref> B<ref name=n />" ), 'a b body' );
	assert.equal( T.wikitextToText( 'No refs at all.' ), 'no refs at all.' );
} );

test( 'wikitextToText: headings, lists, tables, rules', () => {
	assert.equal( T.wikitextToText( '== Features ==\n* One item\n# Two\n; Term : def\n----\nText' ), 'features one item two term : def text' );
	assert.equal(
		T.wikitextToText( '{| class="wikitable"\n|+ Caption\n! Head1 !! Head2\n|-\n| style="x" | a || b\n|}' ),
		'caption head1 head2 a b'
	);
} );

test( 'wikitextToText: PAGENAME substitution when a page name is given', () => {
	assert.equal( T.wikitextToText( 'The {{PAGENAME}} is a ship.', { pageName: 'Aurora MR' } ), 'the aurora mr is a ship.' );
	assert.equal( T.wikitextToText( 'The {{PAGENAME}} is a ship.' ), 'the is a ship.' );
} );

test( 'tokenize: words keep inner apostrophes, punctuation stands alone', () => {
	assert.deepEqual( T.tokenize( 'squadron 42\'s soundtrack, composed by geoff.' ), [ 'squadron', '42\'s', 'soundtrack', ',', 'composed', 'by', 'geoff', '.' ] );
	assert.deepEqual( T.tokenize( '' ), [] );
} );

test( 'makeInterner: equal tokens get equal ids across sequences', () => {
	const intern = T.makeInterner();
	const a = intern( [ 'x', 'y', 'x' ] );
	const b = intern( [ 'y', 'x' ] );
	assert.equal( a[ 0 ], a[ 2 ] );
	assert.equal( a[ 1 ], b[ 0 ] );
	assert.equal( a[ 0 ], b[ 1 ] );
} );

test( 'diffMap: identical, insertion, deletion, replacement, disjoint', () => {
	const A = [ 1, 2, 3, 4, 5 ];
	assert.deepEqual( Array.from( T.diffMap( A, [ 1, 2, 3, 4, 5 ], 100 ) ), [ 0, 1, 2, 3, 4 ] );
	// insert 9 after 2
	assert.deepEqual( Array.from( T.diffMap( A, [ 1, 2, 9, 3, 4, 5 ], 100 ) ), [ 0, 1, -1, 2, 3, 4 ] );
	// delete 3
	assert.deepEqual( Array.from( T.diffMap( A, [ 1, 2, 4, 5 ], 100 ) ), [ 0, 1, 3, 4 ] );
	// replace 3 with 8
	assert.deepEqual( Array.from( T.diffMap( A, [ 1, 2, 8, 4, 5 ], 100 ) ), [ 0, 1, -1, 3, 4 ] );
	// nothing in common
	assert.deepEqual( Array.from( T.diffMap( [ 1, 2 ], [ 7, 8, 9 ], 100 ) ), [ -1, -1, -1 ] );
	// empty sides
	assert.deepEqual( Array.from( T.diffMap( [], [ 1, 2 ], 100 ) ), [ -1, -1 ] );
	assert.deepEqual( Array.from( T.diffMap( [ 1, 2 ], [], 100 ) ), [] );
} );

test( 'diffMap: a moved block matches once, and the cap degrades to full rewrite', () => {
	const a = [ 1, 2, 3, 4, 5, 6, 7, 8 ];
	const b = [ 5, 6, 7, 8, 1, 2, 3, 4 ];
	const m = Array.from( T.diffMap( a, b, 100 ) );
	// Exactly one of the two halves survives as matched, the other reads as inserted.
	const matched = m.filter( ( x ) => x >= 0 ).length;
	assert.equal( matched, 4 );
	// With the cap below the true distance, only prefix/suffix survive (none here).
	assert.deepEqual( Array.from( T.diffMap( a, b, 2 ) ), [ -1, -1, -1, -1, -1, -1, -1, -1 ] );
} );

test( 'diffMap: reports when it gave up rather than when nothing matched', () => {
	const a = [ 1, 2, 3, 4, 5, 6, 7, 8 ];
	const b = [ 5, 6, 7, 8, 1, 2, 3, 4 ];
	const hit = {};
	T.diffMap( a, b, 2, hit );
	assert.equal( hit.capped, true );
	const ok = {};
	T.diffMap( a, b, 100, ok );
	assert.equal( ok.capped, undefined );
} );

test( 'dropPunctuationOnlyRuns: an isolated punctuation match is not evidence', () => {
	const run = ( m, toks ) => Array.from( T.dropPunctuationOnlyRuns( Int32Array.from( m ), toks ) );
	// A lone "." matching somewhere in the source is coincidence.
	assert.deepEqual( run( [ -1, 5, -1 ], [ 'cargo', '.', 'scu' ] ), [ -1, -1, -1 ] );
	// So is a stretch of only punctuation.
	assert.deepEqual( run( [ -1, 5, 6, -1 ], [ 'x', '.', '/', 'y' ] ), [ -1, -1, -1, -1 ] );
	// A real word stands on its own, which is how infobox values are attributed.
	assert.deepEqual( run( [ -1, 5, -1 ], [ 'cargo', '456', 'scu' ] ), [ -1, 5, -1 ] );
	// Punctuation inside a run that holds a word is kept with it.
	assert.deepEqual( run( [ 3, 4, 5 ], [ 'the', 'ship', '.' ] ), [ 3, 4, 5 ] );
	assert.deepEqual( run( [ -1, -1 ], [ '.', '/' ] ), [ -1, -1 ] );
	assert.deepEqual( run( [], [] ), [] );
} );

test( 'duplicateSha1s: only hashes seen more than once, blanks ignored', () => {
	assert.deepEqual( [ ...T.duplicateSha1s( [ 'a', 'b', 'a', 'c' ] ) ], [ 'a' ] );
	assert.deepEqual( [ ...T.duplicateSha1s( [ 'a', 'b', 'c' ] ) ], [] );
	assert.deepEqual( [ ...T.duplicateSha1s( [ 'a', 'b', 'c', 'b', 'a' ] ) ], [ 'b', 'a' ] );
	assert.deepEqual( [ ...T.duplicateSha1s( [ '', '', 'x' ] ) ], [] );
	assert.deepEqual( [ ...T.duplicateSha1s( [] ) ], [] );
} );

// Feed a history to the blamer the way the gadget does and read back the origin
// of each word of the final revision.
function blame( revisions, maxD ) {
	const intern = T.makeInterner();
	const sha1s = revisions.map( ( r ) => r.sha1 );
	const blamer = T.makeBlamer( T.duplicateSha1s( sha1s ), maxD === undefined ? 100 : maxD );
	revisions.forEach( ( r, i ) => {
		if ( !blamer.reuse( r.sha1 ) ) {
			blamer.push( intern( T.tokenize( r.text ) ), i, r.sha1 );
		}
	} );
	return { origins: Array.from( blamer.origins ), capped: blamer.capped };
}

test( 'makeBlamer: inserted words take the inserting revision, edits recolour only changed words', () => {
	const o = blame( [
		{ sha1: 'h0', text: 'the ship is fast.' },
		{ sha1: 'h1', text: 'the ship is very fast.' },
		{ sha1: 'h2', text: 'the ship is very quick.' }
	] ).origins;
	// the ship is very quick .
	assert.deepEqual( o, [ 0, 0, 0, 1, 2, 0 ] );
} );

test( 'makeBlamer: a single-edit revert does not credit the reverter', () => {
	const o = blame( [
		{ sha1: 'h1', text: 'original prose here.' },
		{ sha1: 'h2', text: '' },
		{ sha1: 'h1', text: 'original prose here.' },
		{ sha1: 'h3', text: 'original prose here and more.' }
	] ).origins;
	// original prose here and more .  -> 'and more' come from revision 3
	assert.deepEqual( o, [ 0, 0, 0, 3, 3, 0 ] );
} );

test( 'makeBlamer: a rollback of several edits does not credit the rollbacker', () => {
	// MediaWiki rollback undoes every consecutive edit by the last editor, so the
	// restored state is A,B,C,A — which an adjacent-pair rule cannot see.
	const o = blame( [
		{ sha1: 'h1', text: 'the good text.' },
		{ sha1: 'h2', text: 'the good text. spam one.' },
		{ sha1: 'h3', text: 'the good text. spam one. spam two.' },
		{ sha1: 'h1', text: 'the good text.' }
	] ).origins;
	assert.deepEqual( o, [ 0, 0, 0, 0 ] );
} );

test( 'makeBlamer: restoring a state reached later in the history still inherits it', () => {
	const o = blame( [
		{ sha1: 'h1', text: 'one.' },
		{ sha1: 'h2', text: 'one. two.' },
		{ sha1: 'h3', text: 'one. two. three.' },
		{ sha1: 'h2', text: 'one. two.' },
		{ sha1: 'h4', text: 'one. two. four.' }
	] ).origins;
	// one . two . four .  -> 'two' still belongs to revision 1, 'four' to revision 4
	assert.deepEqual( o, [ 0, 0, 1, 1, 4, 4 ] );
} );

test( 'makeBlamer: counts revisions whose diff hit the cap', () => {
	const long = ( tag, n ) => Array.from( { length: n }, ( x, i ) => tag + i ).join( ' ' );
	const r = blame( [
		{ sha1: 'a', text: long( 'x', 200 ) },
		{ sha1: 'b', text: long( 'y', 200 ) }
	], 4 );
	assert.equal( r.capped, 1 );
	assert.equal( blame( [
		{ sha1: 'a', text: 'one two three' },
		{ sha1: 'b', text: 'one two four' }
	], 100 ).capped, 0 );
} );
