// console.log( '[Gadget-Confetti] Gadget loaded' );
function confettiFromPageSide() {
	confetti({
		particleCount: 100,
		angle: 60,
		spread: 55,
		origin: { x: 0 },
	});
	confetti({
		particleCount: 100,
		angle: 120,
		spread: 55,
		origin: { x: 1 },
	});
}

const confettiCommand = {
	id: 'confetti',
	triggers: [ '/confetti', '🎉', '🎊', '🥳' ],
	label: 'Confetti',
	description: 'Because why not?',
	onResultSelect( item ) {
		confettiFromPageSide();
		// Execute the action, returning 'none' keeps us from navigating away
		return { action: 'none' };
	}
};

// Confetti code is in the ext.gadget.Confetti module
mw.loader.using('ext.gadget.Confetti', () => {
	// Celebrate after edit
	mw.hook('postEdit').add( () => {
		confettiFromPageSide();
	} );

	// Add to Command Palette using the new API
	mw.hook( 'citizen.commandPalette.register' ).add( ( data ) => {
		if ( data && data.register ) {
			data.register( confettiCommand );
		}
	} );
} );
