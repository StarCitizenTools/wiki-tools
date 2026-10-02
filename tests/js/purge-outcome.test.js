'use strict';

const { test } = require( 'node:test' );
const assert = require( 'node:assert/strict' );
const P = require( '../../pages/mediawiki/Gadget-purge-outcome.js' );

const RATE_LIMITED = { code: 'ratelimited', text: 'You\'ve exceeded your rate limit. Please wait some time and try again.', module: 'purge' };

function view( overrides ) {
	return Object.assign( {
		wgAction: 'view',
		wgNamespaceNumber: 0,
		wgArticleId: 42,
		wgRevisionId: 100,
		wgCurRevisionId: 100
	}, overrides );
}

test( 'isPurgeable: the current revision of an existing page', () => {
	assert.equal( P.isPurgeable( view() ), true );
	assert.equal( P.isPurgeable( view( { wgNamespaceNumber: 10 } ) ), true );
} );

test( 'isPurgeable: not while editing, on special pages, missing pages or old revisions', () => {
	assert.equal( P.isPurgeable( view( { wgAction: 'edit' } ) ), false );
	assert.equal( P.isPurgeable( view( { wgAction: 'history' } ) ), false );
	assert.equal( P.isPurgeable( view( { wgNamespaceNumber: -1, wgArticleId: 0 } ) ), false );
	assert.equal( P.isPurgeable( view( { wgArticleId: 0, wgRevisionId: 0, wgCurRevisionId: 0 } ) ), false );
	assert.equal( P.isPurgeable( view( { wgRevisionId: 99 } ) ), false );
} );

test( 'outcomeNotice: purged with links updated reloads with a success notice', () => {
	const notice = P.outcomeNotice( { purge: [ { ns: 0, title: 'Aurora Mk II', purged: true, linkupdate: true } ] } );
	assert.deepEqual( notice, { reload: true, type: 'success', text: 'Page purged.' } );
} );

test( 'outcomeNotice: purged but the links update was refused still reloads, with a warning', () => {
	const notice = P.outcomeNotice( {
		warnings: [ RATE_LIMITED ],
		purge: [ { ns: 0, title: 'Aurora Mk II', purged: true } ]
	} );
	assert.equal( notice.reload, true );
	assert.equal( notice.type, 'warn' );
	assert.equal( notice.text, 'Page purged, but its links and data were not updated: ' + RATE_LIMITED.text );
} );

test( 'outcomeNotice: a refusal arrives as a warning on a successful response, not as a rejection', () => {
	const notice = P.outcomeNotice( {
		warnings: [ RATE_LIMITED ],
		purge: [ { ns: 0, title: 'Aurora Mk II' } ]
	} );
	assert.deepEqual( notice, { reload: false, type: 'error', text: 'Could not purge this page: ' + RATE_LIMITED.text } );
} );

test( 'outcomeNotice: one warning raised by both the purge and the links update is shown once', () => {
	const notice = P.outcomeNotice( {
		warnings: [ RATE_LIMITED, RATE_LIMITED ],
		purge: [ { ns: 0, title: 'Aurora Mk II' } ]
	} );
	assert.equal( notice.text, 'Could not purge this page: ' + RATE_LIMITED.text );
} );

test( 'outcomeNotice: a page deleted since it was loaded', () => {
	const notice = P.outcomeNotice( { purge: [ { ns: 0, title: 'Gone', missing: true } ] } );
	assert.deepEqual( notice, { reload: false, type: 'error', text: 'Could not purge this page: it no longer exists.' } );
} );

test( 'outcomeNotice: an empty or unexpected response is a failure, not a reload', () => {
	assert.equal( P.outcomeNotice( {} ).reload, false );
	assert.equal( P.outcomeNotice( undefined ).reload, false );
	assert.equal( P.outcomeNotice( { purge: [] } ).text, 'Could not purge this page: the server did not confirm the purge.' );
} );

test( 'failureNotice: an API error carries its own message', () => {
	const notice = P.failureNotice( 'blocked', { errors: [ { code: 'blocked', text: 'You have been blocked from editing.' } ] } );
	assert.deepEqual( notice, { type: 'error', text: 'Could not purge this page: You have been blocked from editing.' } );
} );

test( 'failureNotice: a network failure', () => {
	const notice = P.failureNotice( 'http', { xhr: {}, textStatus: 'error', exception: '' } );
	assert.equal( notice.text, 'Could not purge this page: the request failed. Check your connection and try again.' );
} );

test( 'failureNotice: an unknown code falls back to the code itself', () => {
	assert.equal( P.failureNotice( 'readonly', undefined ).text, 'Could not purge this page: readonly' );
} );
