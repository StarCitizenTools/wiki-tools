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
		button.className = 't-quantumupload__button';
		button.textContent = 'Add image';

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

		function resetButton() {
			button.disabled = false;
			button.textContent = 'Add image';
		}

		function start( file ) {
			if ( !/^image\//.test( file.type ) ) {
				mw.notify( 'Please choose an image file.', { type: 'error' } );
				return;
			}

			var filename = targetFilename( base, file );
			var previewUrl = URL.createObjectURL( file );
			var img = el.querySelector( 'img' );
			var originalSrc = img ? img.getAttribute( 'src' ) : null;

			if ( img ) {
				img.setAttribute( 'src', previewUrl );
			}
			button.disabled = true;
			button.textContent = 'Stashing…';

			function revert() {
				if ( img && originalSrc !== null ) {
					img.setAttribute( 'src', originalSrc );
				}
				URL.revokeObjectURL( previewUrl );
				resetButton();
			}

			var api = new mw.Api();
			api.uploadToStash( file, { filename: filename } ).done( function ( finishUpload ) {
				button.textContent = 'Stashed';
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
			msg.textContent = 'Publish as ' + filename + ' under ' + LICENSE_TEMPLATE + '?';

			var ok = document.createElement( 'button' );
			ok.type = 'button';
			ok.className = 't-quantumupload__confirm-ok';
			ok.textContent = 'Confirm';

			var cancel = document.createElement( 'button' );
			cancel.type = 'button';
			cancel.className = 't-quantumupload__confirm-cancel';
			cancel.textContent = 'Cancel';

			bar.appendChild( msg );
			bar.appendChild( ok );
			bar.appendChild( cancel );
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
				ok.textContent = 'Publishing…';

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
					ok.textContent = 'Confirm';
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
