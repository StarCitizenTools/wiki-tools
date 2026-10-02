/*
 * Gadget: Purge — which pages get the Purge item, and what an action=purge
 * response means for the reader. No DOM or mw access, so Node can test it.
 *
 * [[MediaWiki:Gadget-purge.js]]
 * [[MediaWiki:Gadget-purge-outcome.js]]
 *
 * ApiPurge never fails the request over a refused purge: a rate limit or a
 * missing right is a warning on an otherwise successful response, and the page
 * entry simply lacks `purged` (or `linkupdate`, for the links half). Read the
 * entry, not whether the promise resolved.
 */
( function () {
	'use strict';

	const FAILED = 'Could not purge this page: ';

	/**
	 * @param {Object} config wgAction, wgNamespaceNumber, wgArticleId,
	 *  wgRevisionId and wgCurRevisionId, as mw.config.get( [ … ] ) returns them
	 * @return {boolean} The current revision of an existing page is being viewed
	 */
	function isPurgeable( config ) {
		return config.wgAction === 'view' &&
			config.wgNamespaceNumber >= 0 &&
			config.wgArticleId > 0 &&
			config.wgRevisionId === config.wgCurRevisionId;
	}

	// The purge and the links update raise the same rate-limit warning separately.
	function warningText( response ) {
		const texts = ( ( response && response.warnings ) || [] )
			.map( ( warning ) => warning.text )
			.filter( Boolean );
		return texts.filter( ( text, i ) => texts.indexOf( text ) === i ).join( ' ' );
	}

	/**
	 * @param {Object} [response] action=purge for one title, formatversion=2,
	 *  errorformat=plaintext
	 * @return {{reload: boolean, type: string, text: string}} reload is true when the
	 *  page was purged; the notice is then shown after the reload
	 */
	function outcomeNotice( response ) {
		const page = ( response && response.purge && response.purge[ 0 ] ) || {};
		const warning = warningText( response );

		if ( page.purged === true ) {
			if ( page.linkupdate === true ) {
				return { reload: true, type: 'success', text: 'Page purged.' };
			}
			return {
				reload: true,
				type: 'warn',
				text: 'Page purged, but its links and data were not updated: ' + ( warning || 'the server did not confirm the update.' )
			};
		}
		if ( page.missing === true || page.invalid === true ) {
			return { reload: false, type: 'error', text: FAILED + 'it no longer exists.' };
		}
		return { reload: false, type: 'error', text: FAILED + ( warning || 'the server did not confirm the purge.' ) };
	}

	/**
	 * @param {string} code First argument of a rejected mw.Api promise
	 * @param {Object} [data] Second argument: the API response, or for code 'http'
	 *  the jqXHR details
	 * @return {{type: string, text: string}}
	 */
	function failureNotice( code, data ) {
		const error = data && data.errors && data.errors[ 0 ];
		if ( error && error.text ) {
			return { type: 'error', text: FAILED + error.text };
		}
		if ( code === 'http' ) {
			return { type: 'error', text: FAILED + 'the request failed. Check your connection and try again.' };
		}
		return { type: 'error', text: FAILED + code };
	}

	module.exports = {
		isPurgeable,
		outcomeNotice,
		failureNotice
	};
}() );
