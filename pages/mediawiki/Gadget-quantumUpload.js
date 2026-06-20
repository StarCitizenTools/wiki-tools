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

	var NAME_ATTR = 'data-gadget-quantumupload-name';
	var MAINT_CATEGORY = 'Images uploaded via QuantumUpload';
	var LICENSE_TEMPLATE = 'Cc-by-sa-4.0';
	var COMMENT = 'Uploaded via QuantumUpload gadget';

	// Static check / close glyphs for the icon-only Codex buttons; they inherit
	// the button's text colour via currentColor. No user data — innerHTML is safe.
	var ICON_CHECK = '<svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">' +
		'<path d="M4 10.5l4 4 8-9" fill="none" stroke="currentColor" stroke-width="2" ' +
		'stroke-linecap="round" stroke-linejoin="round"/></svg>';
	var ICON_CLOSE = '<svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">' +
		'<path d="M5 5l10 10M15 5L5 15" fill="none" stroke="currentColor" stroke-width="2" ' +
		'stroke-linecap="round"/></svg>';
	var ICON_UPLOAD = '<svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">' +
		'<path d="M10 13V4M6.5 7.5 10 4l3.5 3.5M4 13v3h12v-3" fill="none" stroke="currentColor" ' +
		'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

	// File base + the picked file's extension (jpeg normalised to jpg).
	function targetFilename( base, file ) {
		var ext = ( file.name.split( '.' ).pop() || '' ).toLowerCase();
		if ( ext === 'jpeg' ) {
			ext = 'jpg';
		}
		return base + '.' + ext;
	}

	// File-page wikitext, mirroring the wiki's {{Information}} shape.
	function buildPageText( el ) {
		var pageTitle = mw.config.get( 'wgPageName' ).replace( /_/g, ' ' );
		var desc = el.getAttribute( 'data-gadget-quantumupload-desc' ) ||
			( 'Infobox image for [[' + pageTitle + ']]' );
		var license = el.getAttribute( 'data-gadget-quantumupload-license' ) || LICENSE_TEMPLATE;
		var cats = ( el.getAttribute( 'data-gadget-quantumupload-categories' ) || MAINT_CATEGORY ).split( '|' );
		var date = new Date().toISOString().slice( 0, 10 );
		var catText = cats.map( function ( c ) {
			return '[[Category:' + c.trim() + ']]';
		} ).join( '\n' );

		return '=={{int:filedesc}}==\n' +
			'{{Information\n' +
			'|description={{en|1=' + desc + '}}\n' +
			'|date=' + date + '\n' +
			'|source={{own}}\n' +
			'|author=[[User:' + mw.config.get( 'wgUserName' ) + ']]\n' +
			'|permission=\n' +
			'|other versions=\n' +
			'}}\n\n' +
			'=={{int:license-header}}==\n' +
			'{{' + license + '}}\n\n' +
			catText + '\n';
	}

	function errorText( code, result ) {
		if ( result && result.upload && result.upload.warnings ) {
			if ( result.upload.warnings.duplicate ) {
				return 'That image is already on the wiki.';
			}
			if ( result.upload.warnings.exists ) {
				return 'A file named that already exists.';
			}
		}
		if ( result && result.error && result.error.info ) {
			return result.error.info;
		}
		return 'Upload failed (' + ( code || 'unknown error' ) + ').';
	}

	function enhance( el ) {
		var base = el.getAttribute( NAME_ATTR );
		if ( !base ) {
			return;
		}

		var overlay = document.createElement( 'div' );
		overlay.className = 't-quantumupload';

		var input = document.createElement( 'input' );
		input.type = 'file';
		input.accept = 'image/png,image/jpeg,image/webp,image/gif';
		input.className = 't-quantumupload__input';

		var button = document.createElement( 'button' );
		button.type = 'button';
		button.className = 'cdx-button t-quantumupload__button';
		var buttonIcon = document.createElement( 'span' );
		buttonIcon.className = 'cdx-icon';
		buttonIcon.innerHTML = ICON_UPLOAD;
		button.appendChild( buttonIcon );
		button.appendChild( document.createTextNode( 'Add image' ) );

		overlay.appendChild( button );
		overlay.appendChild( input );
		el.appendChild( overlay );

		button.addEventListener( 'click', function () {
			input.click();
		} );
		input.addEventListener( 'change', function () {
			if ( input.files && input.files[ 0 ] ) {
				start( input.files[ 0 ] );
			}
		} );
		el.addEventListener( 'dragover', function ( e ) {
			e.preventDefault();
			el.classList.add( 't-quantumupload--drag' );
		} );
		el.addEventListener( 'dragleave', function () {
			el.classList.remove( 't-quantumupload--drag' );
		} );
		el.addEventListener( 'drop', function ( e ) {
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

			var filename = targetFilename( base, file );
			var previewUrl = URL.createObjectURL( file );

			// Show the picked image as a local preview and hide the add button.
			// The wiki wraps the placeholder in <picture> with a <source> that
			// overrides the <img> and pins fixed dimensions, so instead of mutating
			// it we hide the whole file markup and drop in our own naturally-sized
			// <img>. `.mw-file-element` is the standard class on any rendered file
			// image, so this stays reusable (not tied to InfoboxLua); we hide its
			// `mw:File` wrapper, falling back to the image itself.
			var img = el.querySelector( '.mw-file-element' );
			var fileMarkup = ( img && img.closest( '[typeof="mw:File"]' ) ) || img;
			var previewHost = ( fileMarkup && fileMarkup.parentNode ) || el;
			// Capture the placeholder's rendered width before hiding it: the host is
			// often a shrink-to-fit float, so once the placeholder is gone a
			// percentage-width preview would collapse. Pinning the width keeps the
			// preview the same size, with natural height (no aspect-ratio stretch).
			var displayWidth = img ? Math.round( img.getBoundingClientRect().width ) : 0;

			var preview = document.createElement( 'img' );
			preview.className = 't-quantumupload__preview';
			preview.src = previewUrl;
			if ( displayWidth ) {
				preview.style.width = displayWidth + 'px';
			}

			if ( fileMarkup ) {
				fileMarkup.style.display = 'none';
				previewHost.insertBefore( preview, fileMarkup.nextSibling );
			} else {
				el.appendChild( preview );
			}
			overlay.style.display = 'none';

			// Uploading overlay: dims the preview and shows an indeterminate loading
			// ring around the border while the (possibly slow) stash upload is in
			// flight. The ring is drawn and animated entirely in CSS
			// (.t-quantumupload__uploading::after); JS only adds/removes the element.
			var uploading = document.createElement( 'div' );
			uploading.className = 't-quantumupload__uploading';
			el.appendChild( uploading );

			function removeUploading() {
				if ( uploading.parentNode ) {
					uploading.parentNode.removeChild( uploading );
				}
			}

			function revert() {
				removeUploading();
				if ( preview.parentNode ) {
					preview.parentNode.removeChild( preview );
				}
				if ( fileMarkup ) {
					fileMarkup.style.display = '';
				}
				URL.revokeObjectURL( previewUrl );
				overlay.style.display = '';
			}

			var api = new mw.Api();
			api.uploadToStash( file, { filename: filename } ).done( function ( finishUpload ) {
				removeUploading();
				showConfirm( filename, finishUpload, revert );
			} ).fail( function ( code, result ) {
				mw.notify( errorText( code, result ), { type: 'error' } );
				revert();
			} );
		}

		function showConfirm( filename, finishUpload, revert ) {
			var bar = document.createElement( 'div' );
			bar.className = 't-quantumupload__confirm';

			var msg = document.createElement( 'span' );
			msg.className = 't-quantumupload__confirm-msg';
			msg.textContent = filename;
			msg.title = 'Publish under ' + LICENSE_TEMPLATE;

			var cancel = document.createElement( 'button' );
			cancel.type = 'button';
			cancel.className = 'cdx-button cdx-button--icon-only cdx-button--weight-quiet t-quantumupload__confirm-cancel';
			cancel.setAttribute( 'aria-label', 'Cancel' );
			cancel.innerHTML = ICON_CLOSE;

			var ok = document.createElement( 'button' );
			ok.type = 'button';
			ok.className = 'cdx-button cdx-button--icon-only cdx-button--weight-primary cdx-button--action-progressive t-quantumupload__confirm-ok';
			ok.setAttribute( 'aria-label', 'Publish image' );
			ok.innerHTML = ICON_CHECK;

			bar.appendChild( msg );
			bar.appendChild( cancel );
			bar.appendChild( ok );
			el.appendChild( bar );
			ok.focus();

			function removeBar() {
				if ( bar.parentNode ) {
					bar.parentNode.removeChild( bar );
				}
			}

			cancel.addEventListener( 'click', function () {
				removeBar();
				revert();
			} );

			ok.addEventListener( 'click', function () {
				ok.disabled = true;
				cancel.disabled = true;

				finishUpload( {
					filename: filename,
					text: buildPageText( el ),
					comment: COMMENT,
					ignorewarnings: false
				} ).done( function () {
					removeBar();
					if ( overlay.parentNode ) {
						overlay.parentNode.removeChild( overlay );
					}
					el.removeAttribute( NAME_ATTR );
					el.classList.remove( 't-infobox-image-container--placeholder' );
					new mw.Api().post( {
						action: 'purge',
						titles: mw.config.get( 'wgPageName' )
					} );
					mw.notify( 'Image published.', { type: 'success' } );
				} ).fail( function ( code, result ) {
					ok.disabled = false;
					cancel.disabled = false;
					mw.notify( errorText( code, result ), { type: 'error' } );
				} );
			} );
		}
	}

	mw.loader.using( [ 'mediawiki.api', 'mediawiki.notification' ] ).then( function () {
		var nodes = document.querySelectorAll( '[' + NAME_ATTR + ']' );
		Array.prototype.forEach.call( nodes, enhance );
	} );

}() );
