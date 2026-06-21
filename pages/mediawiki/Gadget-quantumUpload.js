/*
 * Gadget: QuantumUpload
 *
 * Overlays a one-action image-upload control on infobox placeholders. The Lua
 * side (Module:InfoboxLua) marks a placeholder with
 *   data-gadget-quantumupload-name="<File base, no extension>"
 * when an infobox has no image and no conventionally-named file exists. This
 * gadget — loaded only for users with the `verified-edit` right (gated in
 * MediaWiki:Gadgets-definition) — turns each marker into: pick/drag a file ->
 * upload-stash -> local preview -> confirm -> publish (with auto-filled file
 * page) -> purge the host page so the infobox auto-discovers the new file.
 *
 * Buttons use Codex classes (cdx-button*) which are loaded site-wide.
 *
 * Optional override attributes on the same element:
 *   data-gadget-quantumupload-categories  pipe-separated categories
 *   data-gadget-quantumupload-desc        file-page description text
 *   data-gadget-quantumupload-license     license template name
 */
( function () {
	'use strict';

	const NAME_ATTR = 'data-gadget-quantumupload-name';
	const MAINT_CATEGORY = 'Images uploaded via QuantumUpload';
	const LICENSE_TEMPLATE = 'Cc-by-sa-4.0';
	const COMMENT = 'Uploaded via QuantumUpload gadget';
	// Upload warnings that are benign for an infobox image and shouldn't block the
	// stash: the name was previously deleted (`was-deleted`), or the content matches
	// an already-deleted file (`duplicate-archive`). A *live* conflict — `duplicate`
	// (matches an existing file) or `exists` — and anything else is surfaced instead.
	const BENIGN_WARNINGS = [ 'was-deleted', 'duplicate-archive' ];

	// Static glyphs for the Codex icon buttons; they inherit the button's text
	// colour via currentColor. No user data — innerHTML is safe.
	const ICON_CHECK = '<svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true"><path d="M4 10.5l4 4 8-9" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
	const ICON_CLOSE = '<svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true"><path d="M5 5l10 10M15 5L5 15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>';
	const ICON_UPLOAD = '<svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true"><path d="M10 13V4M6.5 7.5 10 4l3.5 3.5M4 13v3h12v-3" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

	// File base + the picked file's extension (jpeg normalised to jpg).
	function targetFilename( base, file ) {
		let ext = ( file.name.split( '.' ).pop() || '' ).toLowerCase();
		if ( ext === 'jpeg' ) {
			ext = 'jpg';
		}
		return `${ base }.${ ext }`;
	}

	// File-page wikitext, mirroring the wiki's {{Information}} shape.
	function buildPageText( el ) {
		const pageTitle = mw.config.get( 'wgPageName' ).replace( /_/g, ' ' );
		const desc = el.getAttribute( 'data-gadget-quantumupload-desc' ) || `Infobox image for [[${ pageTitle }]]`;
		const license = el.getAttribute( 'data-gadget-quantumupload-license' ) || LICENSE_TEMPLATE;
		// The maintenance category is always present; the emitter may add more.
		const extra = el.getAttribute( 'data-gadget-quantumupload-categories' );
		const cats = [ MAINT_CATEGORY ].concat( extra ? extra.split( '|' ) : [] );
		const date = new Date().toISOString().slice( 0, 10 );
		const catText = cats.map( ( c ) => `[[Category:${ c.trim() }]]` ).join( '\n' );

		return `=={{int:filedesc}}==
{{Information
|description={{en|1=${ desc }}}
|date=${ date }
|source={{own}}
|author=[[User:${ mw.config.get( 'wgUserName' ) }]]
|permission=
|other versions=
}}

=={{int:license-header}}==
{{${ license }}}

${ catText }
`;
	}

	function errorText( code, result ) {
		const warnings = result && result.upload && result.upload.warnings;
		if ( warnings && warnings.duplicate ) {
			return 'That image is already on the wiki.';
		}
		if ( warnings && warnings.exists ) {
			return 'A file with that name already exists.';
		}
		if ( result && result.error && result.error.info ) {
			return result.error.info;
		}
		mw.log.warn( 'QuantumUpload: upload failed', code, result );
		return 'Upload failed. Please try again.';
	}

	// Reuse the Confetti gadget's burst on success. Loaded on demand; a delight,
	// so never block or error the flow if it is unavailable.
	function celebrate() {
		mw.loader.using( 'ext.gadget.Confetti' ).then( () => {
			if ( typeof window.confettiFromPageSide === 'function' ) {
				window.confettiFromPageSide();
			}
		}, () => {} );
	}

	function enhance( el ) {
		const base = el.getAttribute( NAME_ATTR );
		if ( !base ) {
			return;
		}

		const overlay = document.createElement( 'div' );
		overlay.className = 't-quantumupload';

		const input = document.createElement( 'input' );
		input.type = 'file';
		input.accept = 'image/png,image/jpeg,image/webp,image/gif';
		input.className = 't-quantumupload__input';

		const button = document.createElement( 'button' );
		button.type = 'button';
		button.className = 'cdx-button t-quantumupload__button';
		const buttonIcon = document.createElement( 'span' );
		buttonIcon.className = 'cdx-icon';
		buttonIcon.innerHTML = ICON_UPLOAD;
		button.append( buttonIcon, document.createTextNode( 'Add image' ) );

		overlay.append( button, input );
		el.append( overlay );

		button.addEventListener( 'click', () => input.click() );
		input.addEventListener( 'change', () => {
			if ( input.files && input.files[ 0 ] ) {
				start( input.files[ 0 ] );
			}
		} );
		el.addEventListener( 'dragover', ( e ) => {
			e.preventDefault();
			el.classList.add( 't-quantumupload--drag' );
		} );
		el.addEventListener( 'dragleave', () => el.classList.remove( 't-quantumupload--drag' ) );
		el.addEventListener( 'drop', ( e ) => {
			e.preventDefault();
			el.classList.remove( 't-quantumupload--drag' );
			if ( e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[ 0 ] ) {
				start( e.dataTransfer.files[ 0 ] );
			}
		} );

		function start( file ) {
			if ( !/^image\//.test( file.type ) ) {
				mw.notify( 'Please choose an image file.', { type: 'error' } );
				return;
			}

			const filename = targetFilename( base, file );
			const previewUrl = URL.createObjectURL( file );

			// Show the picked image as a local preview and hide the add button.
			// The wiki wraps the placeholder in <picture> with a <source> that
			// overrides the <img> and pins fixed dimensions, so instead of mutating
			// it we hide the whole file markup and drop in our own naturally-sized
			// <img>. `.mw-file-element` is the standard class on any rendered file
			// image, so this stays reusable (not tied to InfoboxLua); we hide its
			// `mw:File` wrapper, falling back to the image itself.
			const img = el.querySelector( '.mw-file-element' );
			const fileMarkup = ( img && img.closest( '[typeof="mw:File"]' ) ) || img;
			const previewHost = ( fileMarkup && fileMarkup.parentNode ) || el;
			// Capture the placeholder's rendered width before hiding it: the host is
			// often a shrink-to-fit float, so once the placeholder is gone a
			// percentage-width preview would collapse. Pinning the width keeps the
			// preview the same size, with natural height (no aspect-ratio stretch).
			const displayWidth = img ? Math.round( img.getBoundingClientRect().width ) : 0;

			const preview = document.createElement( 'img' );
			preview.className = 't-quantumupload__preview';
			preview.src = previewUrl;
			if ( displayWidth ) {
				preview.style.width = `${ displayWidth }px`;
			}

			if ( fileMarkup ) {
				fileMarkup.style.display = 'none';
				previewHost.insertBefore( preview, fileMarkup.nextSibling );
			} else {
				el.append( preview );
			}
			overlay.style.display = 'none';

			// Uploading overlay: dims the preview and shows an indeterminate loading
			// ring around the border while the (possibly slow) stash upload is in
			// flight. The ring is drawn and animated entirely in CSS
			// (.t-quantumupload__uploading::after); JS only adds/removes the element.
			const uploading = document.createElement( 'div' );
			uploading.className = 't-quantumupload__uploading';
			el.append( uploading );

			const removeUploading = () => uploading.remove();

			const revert = () => {
				removeUploading();
				preview.remove();
				if ( fileMarkup ) {
					fileMarkup.style.display = '';
				}
				URL.revokeObjectURL( previewUrl );
				overlay.style.display = '';
				// Clear the picker so re-selecting the same file fires `change` again.
				input.value = '';
			};

			// Stash the file. Warnings reject the upload here (before the file is
			// published); if the file was still stashed (filekey present) and every
			// warning is benign (e.g. the name was previously deleted), proceed to the
			// confirm step. Anything else (duplicate, exists, large-file, …) surfaces.
			new mw.Api().upload( file, { stash: true, filename: filename } ).done( ( result ) => {
				removeUploading();
				showConfirm( filename, result.upload.filekey, revert );
			} ).fail( ( code, result ) => {
				const upload = result && result.upload;
				const keys = ( upload && upload.warnings ) ? Object.keys( upload.warnings ) : [];
				if ( upload && upload.filekey && keys.length && keys.every( ( k ) => BENIGN_WARNINGS.indexOf( k ) !== -1 ) ) {
					removeUploading();
					showConfirm( filename, upload.filekey, revert );
				} else {
					mw.notify( errorText( code, result ), { type: 'error' } );
					revert();
				}
			} );
		}

		function showConfirm( filename, filekey, revert ) {
			const bar = document.createElement( 'div' );
			bar.className = 't-quantumupload__confirm';

			const msg = document.createElement( 'span' );
			msg.className = 't-quantumupload__confirm-msg';
			msg.textContent = filename;
			msg.title = `Publish under ${ LICENSE_TEMPLATE }`;

			const cancel = document.createElement( 'button' );
			cancel.type = 'button';
			cancel.className = 'cdx-button cdx-button--icon-only cdx-button--weight-quiet t-quantumupload__confirm-cancel';
			cancel.setAttribute( 'aria-label', 'Cancel' );
			cancel.innerHTML = ICON_CLOSE;

			const ok = document.createElement( 'button' );
			ok.type = 'button';
			ok.className = 'cdx-button cdx-button--icon-only cdx-button--weight-primary cdx-button--action-progressive t-quantumupload__confirm-ok';
			ok.setAttribute( 'aria-label', 'Publish image' );
			ok.innerHTML = ICON_CHECK;

			bar.append( msg, cancel, ok );
			el.append( bar );
			ok.focus();

			cancel.addEventListener( 'click', () => {
				bar.remove();
				revert();
			} );

			ok.addEventListener( 'click', () => {
				ok.disabled = true;
				cancel.disabled = true;

				const onPublished = () => {
					bar.remove();
					overlay.remove();
					el.removeAttribute( NAME_ATTR );
					el.classList.remove( 't-infobox-image-container--placeholder' );
					// Purge the host page so the infobox re-renders and auto-discovers
					// the new file.
					new mw.Api().post( { action: 'purge', titles: mw.config.get( 'wgPageName' ) } );
					mw.notify( 'Image published.', { type: 'success' } );
					celebrate();
				};

				// Publish the already-stashed, already-vetted file. uploadFromStash
				// rejects whenever the response carries warnings — even when the upload
				// actually succeeded (result === 'Success'), which is exactly what
				// ignorewarnings produces — so treat that case as a success.
				new mw.Api().uploadFromStash( filekey, {
					filename: filename,
					text: buildPageText( el ),
					comment: COMMENT,
					ignorewarnings: true
				} ).done( onPublished ).fail( ( code, result ) => {
					if ( result && result.upload && result.upload.result === 'Success' ) {
						onPublished();
						return;
					}
					ok.disabled = false;
					cancel.disabled = false;
					mw.notify( errorText( code, result ), { type: 'error' } );
				} );
			} );
		}
	}

	mw.loader.using( [ 'mediawiki.api', 'mediawiki.notification' ] ).then( () => {
		document.querySelectorAll( `[${ NAME_ATTR }]` ).forEach( enhance );
	} );

}() );
