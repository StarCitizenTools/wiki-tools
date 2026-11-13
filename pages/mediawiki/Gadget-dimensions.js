/*
 * Gadget: dimensions — makes every Module:Dimensions diagram open a full view
 * of the object's dimensions, where it can be compared with people, everyday
 * objects and cargo containers. This part only enhances the diagram: the view
 * is the hidden dimensionsDialog gadget, loaded on the first click, so pages
 * carry a few lines of script and readers who never open it download no more.
 *
 * [[MediaWiki:Gadget-dimensions.js]]
 * [[MediaWiki:Gadget-dimensions.css]]
 *
 * The object's sizes come from the diagrams' data-length/-width/-height. An
 * infobox may hold two diagrams, the physical size and the stowed (cargo)
 * size, which Module:Dimensions tells apart with data-gadget-dimensions-size.
 */
( function () {
	'use strict';

	const ROOT_SELECTOR = '.t-dimensions';
	const P = 'gadget-dimensions';
	const DIALOG = 'ext.gadget.dimensionsDialog';
	// Codex icons from the gadget definition's codexIcons option.
	const icons = require( './icons.json' );

	/**
	 * @param {HTMLElement} root a .t-dimensions diagram
	 * @return {Object|null} { length, width, height } in metres, or null
	 *  unless all three are positive
	 */
	function readBox( root ) {
		const box = {
			length: parseFloat( root.dataset.length ),
			width: parseFloat( root.dataset.width ),
			height: parseFloat( root.dataset.height )
		};
		return box.length > 0 && box.width > 0 && box.height > 0 ? box : null;
	}

	/**
	 * @param {HTMLElement} root
	 * @return {boolean} the diagram is the stowed (cargo) size
	 */
	function isStowed( root ) {
		return root.dataset.gadgetDimensionsSize === 'stowed';
	}

	/**
	 * The physical and stowed sizes of the object a diagram belongs to: every
	 * diagram in the same infobox describes the same object.
	 *
	 * @param {HTMLElement} root
	 * @return {{name: string, physical: Object|null, stowed: Object|null}}
	 */
	function subjectOf( root ) {
		const infobox = root.closest( '.t-infobox' );
		const diagrams = infobox ? infobox.querySelectorAll( ROOT_SELECTOR ) : [ root ];
		const subject = { name: mw.config.get( 'wgTitle' ), physical: null, stowed: null };
		diagrams.forEach( ( node ) => {
			const box = readBox( node );
			const key = isStowed( node ) ? 'stowed' : 'physical';
			if ( box && !subject[ key ] ) {
				subject[ key ] = box;
			}
		} );
		return subject;
	}

	/**
	 * @param {HTMLElement} root
	 * @param {HTMLElement} opener focused again when the view closes
	 */
	function open( root, opener ) {
		if ( root.classList.contains( `${ P }-loading` ) ) {
			return;
		}
		root.classList.add( `${ P }-loading` );
		mw.loader.using( DIALOG ).then( ( require ) => {
			// A cargo diagram opens on Fit, where its stowed size matters.
			const mode = isStowed( root ) ? 'fit' : 'compare';
			require( DIALOG ).open( subjectOf( root ), mode, opener );
		}, () => {
			mw.notify( 'The dimensions view could not be loaded.', { type: 'error' } );
		} ).always( () => {
			root.classList.remove( `${ P }-loading` );
		} );
	}

	/**
	 * The whole diagram becomes the way in: a button fills the box behind the
	 * diagram, which lets clicks through except on its text, so the
	 * measurements stay selectable and screen readers still read them.
	 *
	 * @param {HTMLElement} root a .t-dimensions diagram
	 */
	function enhance( root ) {
		if ( root.classList.contains( `${ P }-enhanced` ) || !readBox( root ) ) {
			return;
		}
		root.classList.add( `${ P }-enhanced` );
		const button = document.createElement( 'button' );
		button.type = 'button';
		button.className = `${ P }-expand`;
		button.title = 'Expand dimensions';
		button.setAttribute( 'aria-label', 'Expand dimensions' );
		button.setAttribute( 'aria-haspopup', 'dialog' );
		button.addEventListener( 'click', () => open( root, button ) );
		const cue = document.createElement( 'span' );
		cue.className = `${ P }-cue`;
		cue.setAttribute( 'aria-hidden', 'true' );
		cue.innerHTML = `<svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">${ icons.cdxIconFullscreen }</svg>`;
		root.prepend( button );
		root.append( cue );
	}

	mw.hook( 'wikipage.content' ).add( ( $content ) => {
		$content[ 0 ].querySelectorAll( ROOT_SELECTOR ).forEach( enhance );
	} );
}() );
