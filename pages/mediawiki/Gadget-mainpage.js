/*
 * Gadget: mainpage
 *
 * Progressive enhancements for the Main page. Server-rendered markup carries
 * the full no-JS experience; each feature here reads its context from
 * data-gadget-mainpage-<key> attributes and layers behavior on top. Features
 * are independent boot functions — add new ones to EARLY if they only rewrite
 * text the server already rendered, to FEATURES otherwise.
 *
 * Loaded via MediaWiki:Gadgets-definition, gated on
 * categories=Pages using main page gadget, so it ships only on pages that
 * opt in by carrying that category.
 *
 * Features:
 *   heroImage — defers the hero's full-bleed artwork off the critical path.
 *     Contract: <div class="home-hero" data-gadget-mainpage-hero-src="<url>"
 *     data-gadget-mainpage-hero-alt="<alt, optional>"> containing
 *     .home-hero__media. After window load (never competing with first paint),
 *     an <img> is created and faded in via the home-hero--loaded class.
 *     Clients that ask to save data keep the solid ground.
 *
 *   liveStats — turns server-rendered stat numbers into odometers that roll
 *     changed digits upward, and keeps them current from the wiki's own API.
 *     Contract: any element carrying
 *       data-gadget-mainpage-stat="<siteinfo statistics key>"
 *     (articles | edits | users | …) whose text is the rendered number, e.g.
 *       <dd class="home-hero__stat-value" data-gadget-mainpage-stat="edits">376,643</dd>
 *     The number is split into per-digit reels; the plain value is kept in a
 *     visually-hidden span so assistive tech reads a number, not a reel, and
 *     updates stay silent (no aria-live — a counter must not natter).
 *     Polling is same-origin and CDN-cacheable (see the api URL note below), it
 *     reads once on arrival, pauses while the tab is hidden, and backs off on
 *     failure. Without JS the server-rendered number simply stands.
 *
 *   searchReel — rolls the tail of the search label through a few things worth
 *     searching for, then rests on the real label.
 *     Contract: inside the search trigger, the label's tail is its own element
 *       <span class="home-hero__search-label">Search <span
 *         class="home-hero__search-tail"
 *         data-gadget-mainpage-search-tails="a|b|c">the Star Citizen Wiki</span></span>
 *     The element's own text is the resting tail; the attribute lists the
 *     alternatives, pipe-separated, and is authored in wikitext so the
 *     suggestions can be changed without touching this gadget. The reel starts
 *     and ends on the resting tail, so the label is never left saying something
 *     other than what the box is. It runs three cycles and stops — perpetual
 *     motion would owe a pause control under WCAG 2.2.2 — begins only once the
 *     field is on screen, and does not run at all under prefers-reduced-motion.
 *     The reel is aria-hidden behind a visually-hidden copy of the real label,
 *     the same arrangement liveStats uses, so assistive tech reads one stable
 *     phrase. Without JS the server-rendered label simply stands.
 *
 *   countdown — turns an event's dates into a live clock counting days, hours
 *     and minutes, in whichever of the three tenses the dates put it in.
 *     Contract: an element from [[Module:Countdown]] carrying
 *       data-gadget-mainpage-countdown-end="<ISO 8601>"
 *       data-gadget-mainpage-countdown-start="<ISO 8601, optional>"
 *       data-gadget-mainpage-countdown-label="<override, optional>"
 *     whose only child is the server's date range. The module ships dates and
 *     never a duration, because a duration computed at parse time is frozen in
 *     the parser cache and goes quietly wrong; all the arithmetic is here,
 *     against the reader's own clock. Going live replaces the range with a
 *     label and three odometer units and adds t-countdown--live, plus one of
 *     t-countdown--upcoming / --running / --ended, re-asserted every tick so a
 *     card left open across an event's end stops claiming to be running. Those
 *     classes are the ONLY thing the tense publishes, and they go on the
 *     countdown element itself — never on the card around it — so a card can
 *     host a clock without learning what one is. The module's stylesheet owns
 *     what each state looks like. It ticks on the minute rather
 *     than the second — a per-second clock is motion the reader cannot pause,
 *     which WCAG 2.2.2 would make us owe a control for — pauses with the tab,
 *     and rolls only once the card is on screen. Without JS the date range
 *     stands, and unlike a stale duration it never stops being true.
 *
 *   recentActivity — keeps the recent-changes list current and turns its
 *     absolute timestamps into ages. Contract: a container carrying
 *       data-gadget-mainpage-activity
 *       data-gadget-mainpage-activity-limit="<rows>"
 *       data-gadget-mainpage-activity-namespace="<ns id>"
 *     holding .home-act__row children, each with an <a>, a .home-act__by and a
 *     <time class="home-act__when" datetime="<ISO 8601>">. The server renders
 *     the rows with DPL and they stand on their own without JS; this reads
 *     list=recentchanges ONCE, only when the list scrolls into view, off a
 *     CDN-cacheable URL, and ages the labels on the minute thereafter. As with
 *     the countdown the server ships instants and never durations, because a
 *     duration in a parser cache stops being true without saying so.
 */
( function () {
	'use strict';

	const HERO_SRC_ATTR = 'data-gadget-mainpage-hero-src';
	const HERO_ALT_ATTR = 'data-gadget-mainpage-hero-alt';
	const STAT_ATTR = 'data-gadget-mainpage-stat';
	const TAILS_ATTR = 'data-gadget-mainpage-search-tails';
	const COUNTDOWN_START_ATTR = 'data-gadget-mainpage-countdown-start';
	const COUNTDOWN_END_ATTR = 'data-gadget-mainpage-countdown-end';
	const COUNTDOWN_LABEL_ATTR = 'data-gadget-mainpage-countdown-label';
	const ACTIVITY_ATTR = 'data-gadget-mainpage-activity';
	const ACTIVITY_LIMIT_ATTR = 'data-gadget-mainpage-activity-limit';
	const ACTIVITY_NS_ATTR = 'data-gadget-mainpage-activity-namespace';

	const POLL_MS = 60000;
	const MAX_BACKOFF_MS = 960000;
	const CACHE_S = 60;
	const FETCH_TIMEOUT_MS = 10000;
	const ROLL_MS = 520;
	const ROLL_STAGGER_MS = 45;
	const CYCLE = 10;
	const TAIL_STEP_EM = 1.5;
	const TAIL_HOLD_MS = 2600;
	const TAIL_CYCLES = 3;
	const MINUTE_MS = 60000;
	const HOUR_MS = 3600000;
	const DAY_MS = 86400000;
	const COUNTDOWN_UNITS = [ 'Days', 'Hours', 'Minutes' ];
	const ACTIVITY_CACHE_S = 300;
	const ACTIVITY_POOL = 50;
	const ACTIVITY_ROOT_MARGIN = '400px';
	const TEMP_USER_RE = /^~\d{4}-/;
	const RELATIVE_STEPS = [
		{ unit: 'year', span: 31536000000, short: 'y' },
		{ unit: 'month', span: 2592000000, short: 'mo' },
		{ unit: 'week', span: 604800000, short: 'w' },
		{ unit: 'day', span: 86400000, short: 'd' },
		{ unit: 'hour', span: 3600000, short: 'h' },
		{ unit: 'minute', span: 60000, short: 'm' }
	];

	function heroImage() {
		document.querySelectorAll( '.home-hero[' + HERO_SRC_ATTR + ']' ).forEach( ( hero ) => {
			const media = hero.querySelector( '.home-hero__media' );
			const src = hero.getAttribute( HERO_SRC_ATTR );
			if ( !media || !src ) {
				return;
			}
			const conn = navigator.connection;
			if ( conn && conn.saveData ) {
				return;
			}
			const img = document.createElement( 'img' );
			img.alt = hero.getAttribute( HERO_ALT_ATTR ) || '';
			img.decoding = 'async';
			img.addEventListener( 'load', () => hero.classList.add( 'home-hero--loaded' ) );
			img.src = src;
			media.appendChild( img );
		} );
	}

	/**
	 * One stat number, rendered as per-digit reels.
	 *
	 * At rest a digit is a single cell, not a hidden ten-or-more strip: three
	 * nodes per digit instead of thirty-two. The cells a roll travels through are
	 * built for the length of that roll and collapsed again afterwards, so the
	 * Main Page never carries hundreds of permanently invisible spans to animate
	 * a number that changes a couple of times an hour.
	 *
	 * Building the exact path also removes the index bookkeeping entirely: a reel
	 * always starts its roll at cell 0 and ends at cell `steps`, so there is no
	 * cycle to be parked in and no way for a rising value to travel backwards.
	 *
	 * The reels are structural, not the hero's: `.mainpage-odometer*` is styled
	 * by this gadget's own stylesheet and inherits size, weight and colour from
	 * whatever it was built inside, so the same function drives a 13px figure in
	 * the statline and a 3rem digit in an event countdown. Only the visually
	 * hidden readout's class is the caller's, because that one has to be styled
	 * by a stylesheet the caller's markup can count on.
	 *
	 * @param {HTMLElement} node element whose text is the rendered number
	 * @param {Object} options
	 * @param {boolean} options.reduced honour prefers-reduced-motion
	 * @param {Function} options.format number formatter
	 * @param {string} options.srClass class for the visually hidden readout
	 * @return {Object} odometer with node, settle() and set()
	 */
	function makeOdometer( node, options ) {
		const reduced = options.reduced;
		const format = options.format;
		let slots = [];
		let readout = null;
		let shape = '';
		let value = Number( String( node.textContent ).replace( /[^0-9]/g, '' ) ) || 0;
		let settled = false;

		function shapeOf( str ) {
			return str.replace( /[0-9]/g, '#' );
		}

		function cell( digit ) {
			const c = document.createElement( 'span' );
			c.textContent = String( digit );
			return c;
		}

		// Collapse a reel back to the single digit it now shows.
		function rest( slot ) {
			clearTimeout( slot.timer );
			slot.timer = null;
			const reel = slot.reel;
			reel.style.transition = 'none';
			reel.style.transitionDelay = '';
			reel.style.transform = 'translateY(0)';
			reel.textContent = '';
			reel.appendChild( cell( slot.digit ) );
			void reel.offsetHeight;
			reel.style.transition = '';
		}

		// Load a reel with a path of digits and run it. `from`/`to` are cell
		// indices; travelling to a higher index moves the reel upward.
		function run( slot, path, from, to, delay ) {
			if ( slot.timer ) {
				rest( slot );
			}
			const reel = slot.reel;
			reel.textContent = '';
			path.forEach( ( digit ) => reel.appendChild( cell( digit ) ) );
			reel.style.transition = 'none';
			reel.style.transform = 'translateY(-' + from + 'em)';
			void reel.offsetHeight;
			reel.style.transition = '';
			reel.style.transitionDelay = delay ? delay + 'ms' : '';
			reel.style.transform = 'translateY(-' + to + 'em)';
			slot.timer = setTimeout( () => rest( slot ), ROLL_MS + delay + 60 );
		}

		// Roll one digit to `next`, climbing when the number rose.
		function roll( slot, next, rising, delay ) {
			const steps = rising ?
				( next - slot.digit + CYCLE ) % CYCLE :
				( slot.digit - next + CYCLE ) % CYCLE;
			if ( !steps ) {
				return;
			}
			const first = rising ? slot.digit : next;
			const path = [];
			for ( let i = 0; i <= steps; i++ ) {
				path.push( ( first + i ) % CYCLE );
			}
			slot.digit = next;
			run( slot, path, rising ? 0 : steps, rising ? steps : 0, delay );
		}

		// A full turn that lands where it started — the reveal.
		function turn( slot, delay ) {
			const path = [];
			for ( let i = 0; i <= CYCLE; i++ ) {
				path.push( ( slot.digit + i ) % CYCLE );
			}
			run( slot, path, 0, CYCLE, delay );
		}

		function build( str ) {
			slots = [];
			node.textContent = '';

			readout = document.createElement( 'span' );
			readout.className = options.srClass;
			readout.textContent = str;
			node.appendChild( readout );

			const reelRow = document.createElement( 'span' );
			reelRow.className = 'mainpage-odometer';
			reelRow.setAttribute( 'aria-hidden', 'true' );

			str.split( '' ).forEach( ( ch ) => {
				if ( ch >= '0' && ch <= '9' ) {
					const window_ = document.createElement( 'span' );
					window_.className = 'mainpage-odometer__digit';
					const reel = document.createElement( 'span' );
					reel.className = 'mainpage-odometer__reel';
					reel.appendChild( cell( Number( ch ) ) );
					window_.appendChild( reel );
					reelRow.appendChild( window_ );
					slots.push( { reel: reel, digit: Number( ch ), timer: null } );
				} else {
					const sep = document.createElement( 'span' );
					sep.className = 'mainpage-odometer__sep';
					sep.textContent = ch;
					reelRow.appendChild( sep );
				}
			} );

			node.appendChild( reelRow );
			shape = shapeOf( str );
		}

		function render( next, animate ) {
			const str = format( next );

			if ( !slots.length || shapeOf( str ) !== shape ) {
				slots.forEach( ( slot ) => clearTimeout( slot.timer ) );
				build( str );
				value = next;
				return;
			}

			readout.textContent = str;

			const rising = next >= value;
			let cursor = 0;
			str.split( '' ).forEach( ( ch ) => {
				if ( ch < '0' || ch > '9' ) {
					return;
				}
				const slot = slots[ cursor++ ];
				const digit = Number( ch );
				if ( digit === slot.digit ) {
					return;
				}
				if ( !animate || reduced ) {
					slot.digit = digit;
					rest( slot );
					return;
				}
				// Carry propagates leftward: the ones column leads.
				roll( slot, digit, rising, ( slots.length - cursor ) * ROLL_STAGGER_MS );
			} );

			value = next;
		}

		// The reveal: every reel spins one full turn and lands on the digit it
		// started on. Starting from the true value means the resting number is
		// never wrong — only obviously in motion — so a hero that is already on
		// screen at boot never flashes a false figure.
		function settle() {
			if ( settled ) {
				return;
			}
			settled = true;
			if ( reduced ) {
				return;
			}
			slots.forEach( ( slot, i ) => turn( slot, i * ROLL_STAGGER_MS ) );
		}

		render( value, false );

		return {
			node: node,
			settle: settle,
			set: function ( next ) {
				if ( next !== value ) {
					render( next, settled );
				}
			}
		};
	}

	function liveStats() {
		const nodes = document.querySelectorAll( '[' + STAT_ATTR + ']' );
		if ( !nodes.length || typeof mw === 'undefined' ) {
			return;
		}

		const reduced = window.matchMedia( '(prefers-reduced-motion: reduce)' ).matches;
		const format = new Intl.NumberFormat( mw.config.get( 'wgContentLanguage' ) || undefined ).format;
		const meters = [];
		nodes.forEach( ( node ) => meters.push( makeOdometer( node, {
			reduced: reduced,
			format: format,
			srClass: 'home-hero__sr'
		} ) ) );

		// smaxage/maxage make this response public and CDN-cacheable: without them
		// api.php answers `private, must-revalidate, max-age=0` and every reader's
		// poll punches through to MediaWiki. With them the CDN collapses the whole
		// audience into roughly one origin request per window. credentials:'omit'
		// below is load-bearing for the same reason — the response carries
		// `Vary: Cookie`, so sending no cookie keeps logged-in readers on the same
		// shared anonymous cache entry instead of each missing the cache.
		const api = mw.config.get( 'wgScriptPath' ) +
			'/api.php?action=query&meta=siteinfo&siprop=statistics&format=json&formatversion=2' +
			'&maxage=' + CACHE_S + '&smaxage=' + CACHE_S;
		let timer = null;
		let failures = 0;
		let inFlight = null;

		function schedule( ms ) {
			clearTimeout( timer );
			timer = setTimeout( poll, ms );
		}

		function poll() {
			if ( document.hidden ) {
				schedule( POLL_MS );
				return;
			}
			// Returning to the tab calls poll() directly while a timer may also be
			// due, so guard against two reads racing. The abort keeps that guard
			// from wedging the loop if a request never settles.
			if ( inFlight ) {
				return;
			}
			const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
			inFlight = controller || true;
			const giveUp = controller && setTimeout( () => controller.abort(), FETCH_TIMEOUT_MS );
			const done = () => {
				clearTimeout( giveUp );
				inFlight = null;
			};
			fetch( api, { credentials: 'omit', signal: controller ? controller.signal : undefined } )
				.then( ( res ) => res.json() )
				.then( ( data ) => {
					const stats = data && data.query && data.query.statistics;
					if ( !stats ) {
						throw new Error( 'no statistics' );
					}
					failures = 0;
					done();
					meters.forEach( ( meter ) => {
						const key = meter.node.getAttribute( STAT_ATTR );
						if ( typeof stats[ key ] === 'number' ) {
							meter.set( stats[ key ] );
						}
					} );
					schedule( POLL_MS );
				} )
				.catch( () => {
					failures++;
					done();
					schedule( Math.min( POLL_MS * Math.pow( 2, failures ), MAX_BACKOFF_MS ) );
				} );
		}

		// Roll in when the numbers are actually on screen, Stripe-style.
		if ( 'IntersectionObserver' in window ) {
			const seen = new IntersectionObserver( ( entries ) => {
				entries.forEach( ( entry ) => {
					if ( entry.isIntersecting ) {
						meters.forEach( ( meter ) => meter.settle() );
						seen.disconnect();
					}
				} );
			}, { threshold: 0.4 } );
			seen.observe( meters[ 0 ].node );
		} else {
			meters.forEach( ( meter ) => meter.settle() );
		}

		document.addEventListener( 'visibilitychange', () => {
			if ( !document.hidden ) {
				poll();
			}
		} );

		// One read on arrival: {{NUMBEROFEDITS}} and friends are parser-cached and
		// can be hours stale, so this is the correction the reveal actually rolls.
		poll();
	}

	/**
	 * Roll the search label's tail through a short list of suggestions.
	 *
	 * The strip is built once and stepped with a single transform per roll —
	 * the same mechanism, easing and duration as the stat odometer directly
	 * above it, so the two read as one idea rather than two effects competing
	 * in the same corner of the hero.
	 */
	function searchReel() {
		const tail = document.querySelector( '[' + TAILS_ATTR + ']' );
		if ( !tail ) {
			return;
		}
		if ( window.matchMedia( '(prefers-reduced-motion: reduce)' ).matches ) {
			return;
		}

		const resting = tail.textContent.trim();
		const others = ( tail.getAttribute( TAILS_ATTR ) || '' )
			.split( '|' )
			.map( ( t ) => t.trim() )
			.filter( ( t ) => t && t !== resting );
		if ( !others.length ) {
			return;
		}

		// Start AND end on the real tail: the strip's last cell repeats the
		// first, so the roll always lands on the label and the snap back to
		// cell 0 is invisible.
		const path = [ resting ].concat( others ).concat( [ resting ] );

		// A visually-hidden copy carries the real label for assistive tech; it
		// sits outside the reel because the reel itself is aria-hidden.
		const readout = document.createElement( 'span' );
		readout.className = 'home-hero__sr';
		readout.textContent = resting;
		tail.parentNode.insertBefore( readout, tail );

		const reel = document.createElement( 'span' );
		reel.className = 'home-hero__search-reel';
		path.forEach( ( text ) => {
			const cell = document.createElement( 'span' );
			cell.textContent = text;
			reel.appendChild( cell );
		} );

		tail.setAttribute( 'aria-hidden', 'true' );
		tail.textContent = '';
		tail.appendChild( reel );

		let index = 0;
		let cycles = 0;
		let timer = null;

		function snap() {
			reel.style.transition = 'none';
			reel.style.transform = 'translateY(0)';
			index = 0;
			void reel.offsetHeight;
			reel.style.transition = '';
		}

		function step() {
			index += 1;
			reel.style.transform = 'translateY(-' + ( index * TAIL_STEP_EM ) + 'em)';
			if ( index >= path.length - 1 ) {
				cycles += 1;
				setTimeout( snap, ROLL_MS + 60 );
			}
		}

		function schedule() {
			if ( cycles >= TAIL_CYCLES ) {
				return;
			}
			timer = setTimeout( () => {
				step();
				schedule();
			}, TAIL_HOLD_MS );
		}

		// Only once it is actually on screen, so the three cycles are not spent
		// above the fold of someone who never looks.
		if ( 'IntersectionObserver' in window ) {
			const seen = new IntersectionObserver( ( entries ) => {
				entries.forEach( ( entry ) => {
					if ( entry.isIntersecting ) {
						schedule();
						seen.disconnect();
					}
				} );
			}, { threshold: 0.5 } );
			seen.observe( tail );
		} else {
			schedule();
		}

		document.addEventListener( 'visibilitychange', () => {
			if ( document.hidden && timer ) {
				clearTimeout( timer );
				timer = null;
			} else if ( !document.hidden && !timer ) {
				schedule();
			}
		} );
	}

	/**
	 * One event countdown, driven by the reader's own clock.
	 *
	 * The server hands over two dates and a date range; everything a reader sees
	 * as a duration is worked out here, on every tick, because a duration is the
	 * one thing a parser cache cannot hold without eventually lying about it.
	 *
	 * Which of the three tenses applies is a property of now, not of the markup,
	 * so it is recomputed each minute rather than latched at boot: a card left
	 * open across the end of an event rewrites itself from "Ends" to "Ended"
	 * without a reload, and one opened before the event starts counts down to
	 * the opening and then keeps going to the close.
	 *
	 * @param {HTMLElement} node element carrying the countdown attributes
	 * @param {boolean} reduced honour prefers-reduced-motion
	 */
	function makeCountdown( node, reduced ) {
		const ends = Date.parse( node.getAttribute( COUNTDOWN_END_ATTR ) );
		const startsAttr = node.getAttribute( COUNTDOWN_START_ATTR );
		const starts = startsAttr ? Date.parse( startsAttr ) : NaN;
		const override = node.getAttribute( COUNTDOWN_LABEL_ATTR );

		// An unreadable date leaves the server's range standing, which is the
		// right failure: a range nobody animated still tells the truth.
		if ( isNaN( ends ) ) {
			return;
		}

		const meters = [];
		let label = null;
		let timer = null;

		function pad( n ) {
			return n < 10 ? '0' + n : String( n );
		}

		// Which side of the dates the reader is standing on. `past` is not only a
		// choice of words: it flips the clock from counting down to a moment to
		// counting up away from one, which is also what decides when the next
		// minute lands.
		//
		// The words are one syllable shorter than they read: "Ends" against
		// "Ended" is a tense pair, so the verb carries the direction the
		// preposition used to. That matters because this clock counts BOTH ways —
		// down while running, up once finished — and a label that only named the
		// state ("Active") would leave "02 DAYS" meaning either.
		function reading( now ) {
			const early = !isNaN( starts ) && now < starts;
			const at = early ? starts : ends;
			const past = !early && now >= ends;
			let text = 'Ends';
			if ( early ) {
				text = 'Coming';
			} else if ( past ) {
				text = 'Ended';
			}
			return {
				at: at,
				past: past,
				early: early,
				label: override || text,
				delta: Math.abs( at - now )
			};
		}

		function parts( delta ) {
			return [
				Math.floor( delta / DAY_MS ),
				Math.floor( ( delta % DAY_MS ) / HOUR_MS ),
				Math.floor( ( delta % HOUR_MS ) / MINUTE_MS )
			];
		}

		function build( state ) {
			const values = parts( state.delta );
			node.textContent = '';

			label = document.createElement( 'div' );
			label.className = 't-countdown__label';
			label.textContent = state.label;
			node.appendChild( label );

			COUNTDOWN_UNITS.forEach( ( name, i ) => {
				const unit = document.createElement( 'div' );
				unit.className = 't-countdown__unit';
				const value = document.createElement( 'span' );
				value.className = 't-countdown__value';
				// Seed the real figure, not a placeholder: the odometer reads its
				// starting value off this text, and a two-digit seed under a
				// three-digit count would make it rebuild itself immediately.
				value.textContent = pad( values[ i ] );
				const caption = document.createElement( 'span' );
				caption.className = 't-countdown__unit-label';
				caption.textContent = name;
				unit.appendChild( value );
				unit.appendChild( caption );
				node.appendChild( unit );
				meters.push( makeOdometer( value, {
					reduced: reduced,
					format: pad,
					srClass: 't-countdown__sr'
				} ) );
			} );

			// Last, so the grid is only asked to lay out a finished clock.
			node.classList.add( 't-countdown--live' );
		}

		function tick() {
			const state = reading( Date.now() );
			label.textContent = state.label;
			parts( state.delta ).forEach( ( value, i ) => meters[ i ].set( value ) );

			// Re-asserted every minute, not latched at boot: a card left open
			// across the end of an event has to stop claiming to be running. The
			// classes go on the countdown and nowhere else, so the card hosting it
			// needs to know nothing about clocks.
			node.classList.toggle( 't-countdown--upcoming', state.early );
			node.classList.toggle( 't-countdown--running', !state.early && !state.past );
			node.classList.toggle( 't-countdown--ended', state.past );

			// Sleep to the next boundary instead of polling for it. Counting
			// down, the display changes when the remainder runs out; counting up,
			// when it fills. One timer a minute either way, and re-reading the
			// clock each time means it cannot drift.
			let wait = state.past ?
				MINUTE_MS - ( state.delta % MINUTE_MS ) :
				state.delta % MINUTE_MS;
			if ( wait <= 0 ) {
				wait = MINUTE_MS;
			}
			timer = setTimeout( tick, wait );
		}

		build( reading( Date.now() ) );

		// Digits roll only once the card is actually on screen, the same rule the
		// statline follows, so the reveal is not spent above someone's fold.
		if ( 'IntersectionObserver' in window ) {
			const seen = new IntersectionObserver( ( entries ) => {
				entries.forEach( ( entry ) => {
					if ( entry.isIntersecting ) {
						meters.forEach( ( meter ) => meter.settle() );
						seen.disconnect();
					}
				} );
			}, { threshold: 0.4 } );
			seen.observe( node );
		} else {
			meters.forEach( ( meter ) => meter.settle() );
		}

		// A hidden tab holds no timer; coming back re-reads the clock rather than
		// resuming from where it was, so time passed away from the page is simply
		// caught up on.
		document.addEventListener( 'visibilitychange', () => {
			if ( document.hidden ) {
				clearTimeout( timer );
				timer = null;
			} else if ( !timer ) {
				tick();
			}
		} );

		tick();
	}

	function countdown() {
		const nodes = document.querySelectorAll( '[' + COUNTDOWN_END_ATTR + ']' );
		if ( !nodes.length ) {
			return;
		}
		const reduced = window.matchMedia( '(prefers-reduced-motion: reduce)' ).matches;
		nodes.forEach( ( node ) => makeCountdown( node, reduced ) );
	}

	/**
	 * The recent-activity list: what the wiki has been doing, in the last few
	 * minutes rather than the last hour.
	 *
	 * The rows are server-rendered by DPL and are the entire feature with JS off.
	 * What this adds is the two things a parser cache cannot do:
	 *
	 *   Freshness. DPL renders inside the page's parser cache — an hour here —
	 *   and the HTML sits behind the CDN on top of that, so a list headed
	 *   "recently updated" can be hours old before anyone notices. One read of
	 *   list=recentchanges corrects it.
	 *
	 *   Relative time. The server ships an absolute ISO timestamp in <time
	 *   datetime> and never a duration, for exactly the reason the countdown
	 *   does: a duration computed at parse time is frozen in the cache and goes
	 *   quietly wrong. "4h" is worked out here against the reader's own clock and
	 *   re-checked on the minute.
	 *
	 * Cost is the whole design constraint, so:
	 *
	 *   ONE request per reader, and only if they scroll far enough to see the
	 *   list. No polling — unlike the statline, this list has no business
	 *   re-sorting itself under someone's cursor, so it reads once and thereafter
	 *   only ages its own labels.
	 *
	 *   maxage/smaxage make the response public and CDN-cacheable; without them
	 *   api.php answers `private, must-revalidate, max-age=0` and every reader
	 *   punches through to MediaWiki. At 300s the CDN collapses the whole
	 *   audience into roughly a dozen origin reads an hour, and maxage means a
	 *   reader who comes back inside the window spends no request at all.
	 *   credentials:'omit' is load-bearing for the same reason it is above: the
	 *   response carries `Vary: Cookie`, so sending no cookie keeps logged-in
	 *   readers on the shared anonymous cache entry instead of each one missing.
	 *
	 *   It is deliberately NOT folded into the statline's poll, which would be
	 *   one fewer round trip. A combined query has to be re-fetched on the
	 *   shortest cadence in it, which would put the more expensive half of the
	 *   pair on the more volatile half's 60s schedule.
	 *
	 * Contract: a container carrying
	 *   data-gadget-mainpage-activity           (marks the list)
	 *   data-gadget-mainpage-activity-limit     (rows to show; matches DPL count)
	 *   data-gadget-mainpage-activity-namespace (namespace id to read)
	 * holding rows of
	 *   <div class="home-act__row"><a>Page</a>
	 *     <span class="home-act__by">User</span>
	 *     <time class="home-act__when" datetime="<ISO 8601>">…</time></div>
	 */
	function recentActivity() {
		const list = document.querySelector( '[' + ACTIVITY_ATTR + ']' );
		if ( !list || typeof mw === 'undefined' ) {
			return;
		}

		const limit = Number( list.getAttribute( ACTIVITY_LIMIT_ATTR ) ) || 8;
		const namespace = list.getAttribute( ACTIVITY_NS_ATTR ) || '0';
		const lang = mw.config.get( 'wgUserLanguage' ) ||
			mw.config.get( 'wgContentLanguage' ) || undefined;
		const relative = typeof Intl !== 'undefined' && Intl.RelativeTimeFormat ?
			new Intl.RelativeTimeFormat( lang, { numeric: 'auto' } ) : null;
		const absolute = typeof Intl !== 'undefined' && Intl.DateTimeFormat ?
			new Intl.DateTimeFormat( lang, { dateStyle: 'medium', timeStyle: 'short' } ) : null;
		let timer = null;

		/**
		 * Write one timestamp as an age.
		 *
		 * Compact on purpose. This column sits at the end of a single-line row
		 * and has to hold still: "4h" keeps its width from one minute to the
		 * next, where "4 hours ago" becoming "5 hours ago" would shift the row
		 * under the reader. The long form is not lost — it goes to aria-label,
		 * so a screen reader hears a phrase rather than "four h", and to title
		 * for a pointer, which also gets the absolute date.
		 *
		 * @param {HTMLElement} node the <time> element
		 * @param {number} now epoch ms to measure against
		 */
		function stamp( node, now ) {
			const iso = node.getAttribute( 'datetime' );
			const at = Date.parse( iso );
			if ( isNaN( at ) ) {
				return;
			}
			// Clamped at zero: a reader whose clock is a minute slow should see
			// "now", not a negative age counting the wrong way.
			const delta = Math.max( 0, now - at );
			let text = 'now';
			let phrase = 'just now';
			for ( let i = 0; i < RELATIVE_STEPS.length; i++ ) {
				const step = RELATIVE_STEPS[ i ];
				const n = Math.floor( delta / step.span );
				if ( n >= 1 ) {
					text = n + step.short;
					phrase = relative ? relative.format( -n, step.unit ) : text;
					break;
				}
			}
			if ( node.textContent === text ) {
				return;
			}
			node.textContent = text;
			node.setAttribute( 'aria-label', phrase );
			node.title = absolute ? phrase + ' — ' + absolute.format( at ) : iso;
		}

		// Re-read on the minute boundary rather than every sixty seconds from
		// boot, so the whole column turns over together instead of each row
		// drifting by whatever second it was first painted on. stamp() bails on
		// an unchanged label, so a list of week-old edits costs no DOM writes.
		function age() {
			const now = Date.now();
			list.querySelectorAll( 'time[datetime]' ).forEach( ( node ) => stamp( node, now ) );
			timer = setTimeout( age, MINUTE_MS - ( now % MINUTE_MS ) );
		}

		// Temporary accounts read as machine noise in a list whose whole point
		// is recognising people. The real name stays in title, so a change is
		// still traceable to whoever made it.
		function credit( node, user ) {
			if ( TEMP_USER_RE.test( user ) ) {
				node.textContent = 'anonymous';
				node.title = user;
			} else {
				node.textContent = user;
			}
		}

		// mw.util.wikiUrlencode, inlined rather than depended on: this gadget
		// otherwise needs no ResourceLoader modules, and a bare
		// encodeURIComponent would escape the slashes out of every subpage.
		function pageUrl( title ) {
			const encoded = encodeURIComponent( String( title ).replace( / /g, '_' ) )
				.replace( /'/g, '%27' )
				.replace( /%20/g, '_' )
				.replace( /%3B/g, ';' )
				.replace( /%40/g, '@' )
				.replace( /%24/g, '$' )
				.replace( /%2C/g, ',' )
				.replace( /%2F/g, '/' )
				.replace( /%3A/g, ':' );
			return mw.config.get( 'wgArticlePath' ).replace( '$1', encoded );
		}

		function buildRow( change ) {
			const row = document.createElement( 'div' );
			row.className = 'home-act__row';

			const link = document.createElement( 'a' );
			link.href = pageUrl( change.title );
			link.title = change.title;
			link.textContent = change.title;
			row.appendChild( link );

			const by = document.createElement( 'span' );
			by.className = 'home-act__by';
			credit( by, change.user || '' );
			row.appendChild( by );

			const when = document.createElement( 'time' );
			when.className = 'home-act__when';
			when.setAttribute( 'datetime', change.timestamp );
			row.appendChild( when );

			return row;
		}

		// What is on screen now, as page|instant pairs. Compared by parsed
		// instant and not by string: DPL writes `+00:00` where the API writes
		// `Z`, and two spellings of the same moment must not read as a change.
		function signature( rows ) {
			return rows.map( ( row ) => {
				const link = row.querySelector( 'a' );
				const when = row.querySelector( 'time[datetime]' );
				return ( link ? link.title || link.textContent : '' ) + '|' +
					( when ? Date.parse( when.getAttribute( 'datetime' ) ) : '' );
			} ).join( '\n' );
		}

		function apply( changes ) {
			const seen = Object.create( null );
			const fresh = [];
			for ( let i = 0; i < changes.length && fresh.length < limit; i++ ) {
				const change = changes[ i ];
				// One row per page. A page edited four times this morning is one
				// thing that changed, not four; recentchanges is per revision, so
				// the collapse happens here, over a pool deliberately larger than
				// the list so eight distinct pages actually come out of it.
				if ( !change.title || seen[ change.title ] ) {
					continue;
				}
				seen[ change.title ] = true;
				fresh.push( change );
			}
			if ( !fresh.length ) {
				return;
			}

			const wanted = fresh
				.map( ( c ) => c.title + '|' + Date.parse( c.timestamp ) )
				.join( '\n' );
			// Nothing has happened since the page was rendered: leave the DOM
			// alone rather than swapping identical rows under the reader.
			if ( wanted === signature( Array.prototype.slice.call(
				list.querySelectorAll( '.home-act__row' )
			) ) ) {
				return;
			}

			list.textContent = '';
			fresh.forEach( ( change ) => list.appendChild( buildRow( change ) ) );
			const now = Date.now();
			list.querySelectorAll( 'time[datetime]' ).forEach( ( node ) => stamp( node, now ) );
		}

		function load() {
			const api = mw.config.get( 'wgScriptPath' ) +
				'/api.php?action=query&list=recentchanges&format=json&formatversion=2' +
				'&rcprop=title%7Ctimestamp%7Cuser&rctype=edit%7Cnew&rcshow=%21bot' +
				'&rcnamespace=' + encodeURIComponent( namespace ) +
				'&rclimit=' + ACTIVITY_POOL +
				'&maxage=' + ACTIVITY_CACHE_S + '&smaxage=' + ACTIVITY_CACHE_S;
			const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
			const giveUp = controller && setTimeout( () => controller.abort(), FETCH_TIMEOUT_MS );
			fetch( api, {
				credentials: 'omit',
				signal: controller ? controller.signal : undefined
			} )
				.then( ( res ) => res.json() )
				.then( ( data ) => {
					clearTimeout( giveUp );
					const changes = data && data.query && data.query.recentchanges;
					if ( changes && changes.length ) {
						apply( changes );
					}
				} )
				// A failed read leaves the server's rows standing, which is the
				// right failure: an hour-old list is still a true one.
				.catch( () => clearTimeout( giveUp ) );
		}

		// The server's own rows get the same treatment before anything is
		// fetched, so the raw ISO stamps and any temporary account names are
		// gone by first paint whether or not the read ever lands.
		list.querySelectorAll( '.home-act__by' ).forEach(
			( node ) => credit( node, node.textContent.trim() )
		);
		age();

		document.addEventListener( 'visibilitychange', () => {
			if ( document.hidden ) {
				clearTimeout( timer );
				timer = null;
			} else if ( !timer ) {
				age();
			}
		} );

		// Only pay for the read if the list is going to be looked at. A reader
		// who never scrolls past the hero costs nothing at all; the margin means
		// the swap has already happened by the time the card arrives.
		if ( 'IntersectionObserver' in window ) {
			const seen = new IntersectionObserver( ( entries ) => {
				entries.forEach( ( entry ) => {
					if ( entry.isIntersecting ) {
						seen.disconnect();
						load();
					}
				} );
			}, { rootMargin: ACTIVITY_ROOT_MARGIN } );
			seen.observe( list );
		} else {
			load();
		}
	}

	// Two boot points. Anything that only rewrites text the server already
	// rendered runs at DOM ready, so a reader is never left looking at the raw
	// value it is there to replace; anything that fetches, animates or pulls an
	// image waits for window load and stays off the critical path. The activity
	// list is in the first group and still costs nothing early — its one read is
	// gated on the list coming into view, not on this.
	const EARLY = [ recentActivity ];
	const FEATURES = [ heroImage, liveStats, searchReel, countdown ];

	function run( features ) {
		features.forEach( ( feature ) => feature() );
	}

	if ( document.readyState === 'loading' ) {
		document.addEventListener( 'DOMContentLoaded', () => run( EARLY ) );
	} else {
		run( EARLY );
	}

	if ( document.readyState === 'complete' ) {
		run( FEATURES );
	} else {
		window.addEventListener( 'load', () => run( FEATURES ) );
	}
}() );