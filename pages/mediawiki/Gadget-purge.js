/*
 * Gadget: Purge — a Purge item in the page's More menu (p-cactions) that purges
 * the page, runs its links update, and reloads it.
 *
 * [[MediaWiki:Gadget-purge.js]]
 * [[MediaWiki:Gadget-purge-outcome.js]]
 *
 * forcelinkupdate is always sent: Bucket rows and categories are written only
 * by a links update, so a bare purge re-renders the page but leaves its stored
 * data stale.
 *
 * Citizen closes the More card on any link click, so progress and errors are
 * mw.notify toasts rather than state on the menu item.
 */
( function () {
	'use strict';

	const outcome = require( './purge-outcome.js' );

	const LABEL = 'Purge';
	const BUSY_LABEL = 'Purging…';
	const TOOLTIP = 'Purge the cache of this page and update its links and data';
	// One tag, so each toast replaces the previous one instead of stacking.
	const NOTIFY_TAG = 'gadget-purge';
	// Carries the result across the reload: a reload of a page that did not
	// change is otherwise indistinguishable from nothing having happened.
	const STORAGE_KEY = 'gadget-purge-notice';

	function showStoredNotice() {
		const notice = mw.storage.session.getObject( STORAGE_KEY );
		if ( !notice ) {
			return;
		}
		mw.storage.session.remove( STORAGE_KEY );
		if ( notice.page === mw.config.get( 'wgPageName' ) ) {
			mw.notify( notice.text, { type: notice.type, tag: NOTIFY_TAG } );
		}
	}

	function addItem() {
		const item = mw.util.addPortletLink(
			'p-cactions',
			mw.util.getUrl( null, { action: 'purge' } ),
			LABEL,
			'ca-purge',
			TOOLTIP
		);
		if ( !item ) {
			return;
		}
		const link = item.querySelector( 'a' );
		// The label is wrapped only where the skin configures a text wrapper.
		const label = link.querySelector( 'span' ) || link;
		if ( mw.config.get( 'skin' ) === 'citizen' ) {
			// addPortletLink takes no icon on 1.46. This is the markup Citizen
			// renders for its own menu items; the reload icon ships in skins.citizen.icons.
			const icon = document.createElement( 'span' );
			icon.className = 'citizen-ui-icon mw-ui-icon-reload mw-ui-icon-wikimedia-reload';
			link.prepend( icon, ' ' );
		}

		let busy = false;
		function setBusy( value ) {
			busy = value;
			label.textContent = value ? BUSY_LABEL : LABEL;
			if ( value ) {
				link.setAttribute( 'aria-disabled', 'true' );
			} else {
				link.removeAttribute( 'aria-disabled' );
			}
		}

		function fail( notice ) {
			setBusy( false );
			mw.notify( notice.text, { type: notice.type, tag: NOTIFY_TAG, autoHideSeconds: 'long' } );
		}

		link.addEventListener( 'click', ( event ) => {
			// A modified click follows the href, MediaWiki's own purge form.
			if ( event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey ) {
				return;
			}
			event.preventDefault();
			if ( busy ) {
				return;
			}
			setBusy( true );
			mw.notify( BUSY_LABEL, { tag: NOTIFY_TAG, autoHide: false } );
			new mw.Api().post( {
				action: 'purge',
				titles: mw.config.get( 'wgPageName' ),
				forcelinkupdate: 1,
				formatversion: 2,
				errorformat: 'plaintext'
			} ).then( ( response ) => {
				const notice = outcome.outcomeNotice( response );
				if ( !notice.reload ) {
					fail( notice );
					return;
				}
				mw.storage.session.setObject( STORAGE_KEY, {
					page: mw.config.get( 'wgPageName' ),
					type: notice.type,
					text: notice.text
				} );
				location.reload();
			}, ( code, data ) => {
				fail( outcome.failureNotice( code, data ) );
			} );
		} );
	}

	$( () => {
		showStoredNotice();
		if ( outcome.isPurgeable( mw.config.get( [
			'wgAction',
			'wgNamespaceNumber',
			'wgArticleId',
			'wgRevisionId',
			'wgCurRevisionId'
		] ) ) ) {
			addItem();
		}
	} );
}() );
