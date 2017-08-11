# Node
fs = require 'fs'

# Local
Resolver                           = require './Resolver'
{UserException, ResolverException} = require './Exceptions'
debug                              = require('./debug') 'DATC'
Board                              = require './Board'
Engine = require './Engine'

{outcomes: {SUCCEEDS, FAILS, ILLEGAL, EXISTS}} = require './enums'

datc = (board) ->
	engine = Engine board
	t = engine.testMoves.bind engine
	r = engine.testRetreats.bind engine
	b = engine.testBuilds.bind engine

	console.log "Running DATC tests....\n"

	console.log "Testing Moves"
	console.log "-------------"

	# Fails but not ILLEGAL because we don't explicitly check for a convoy path
	# before the order is resolved.
	t 'Illegal move - move to non-adjacent region',
		'Austria: F Budapest - Moscow', FAILS

	t 'Illegal move - Army to sea',
		'England: A Liverpool - Irish Sea', FAILS

	t 'Illegal move - Fleet to land',
		'Germany: F Kiel - Munich', FAILS

	t 'Illegal move - Unit to its own region',
		'Germany: F Kiel - Kiel', ILLEGAL

	t 'Illegal move - Unit convoy to its own region',
		'England: F North Sea Convoys A Yorkshire - Yorkshire', ILLEGAL
		'England: A Yorkshire - Yorkshire', ILLEGAL
		'England: A Liverpool Supports A Yorkshire - Yorkshire', ILLEGAL
		'Germany: F London - Yorkshire', SUCCEEDS
		'Germany: A Wales Supports F London - Yorkshire', SUCCEEDS

	# NOTE: 6.A.6 doesn't belong here (implementation differences) and
	# should be tested elsewhere (be sure to add orders in such a way that
	# the user is checked for their country first, i.e., no orders will
	# ever exist for the wrong country at this level)

	t 'Illegal move - Only armies can be convoyed',
		# TODO: This should probably be illegal but it's pretty inconsequential
		# except for when inputting orders via the UI. Additionally, this kind
		# of thing is actually handled in hasPath which is convenient. Inside
		# the evaluation of the convoy order itself some work would have to be
		# done to get the unit type in the from region of the convoy order.
		# Especially difficult in testing where the units are simply implied
		# from the orders.
		'England: F London - Belgium', FAILS
		'England: F North Sea Convoys A London - Belgium', SUCCEEDS

	t 'Illegal support - An army cannot support itself to hold',
		'Italy: A Venice - Trieste', SUCCEEDS
		'Italy: A Tyrolia Supports A Venice - Trieste', SUCCEEDS
		'Austria: F Trieste Supports F Trieste - Trieste', ILLEGAL

	t 'Illegal move - Fleets must follow coast if not on sea',
		'Italy: F Rome - Venice', FAILS

	t 'Illegal support - Support on unreachable destination not possible',
		'Austria: A Venice Hold', SUCCEEDS
		'Italy: F Rome Supports A Apulia - Venice', ILLEGAL
		# 'Italy: A Apulia - Venice', FAILS

	t 'Regular bounce - Two armies bouncing with each other',
		'Austria: A Vienna - Tyrolia', FAILS
		'Italy: A Venice - Tyrolia', FAILS

	t 'Regular bounce - Three armies bouncing with each other',
		'Austria: A Vienna - Tyrolia', FAILS
		'Germany: A Munich - Tyrolia', FAILS
		'Italy: A Venice - Tyrolia', FAILS

	t 'Coastal issues - Coast not specified',
		'France: F Portugal - Spain', FAILS

	t 'Coastal issues - illegal coast',
		'France: F Gascony - Spain(sc)', FAILS

	t 'Coastal issues - fleet support to non adjacent coast',
		'France: F Gascony - Spain(nc)', SUCCEEDS
		# 'France: F Marseilles Supports F Gascony - Spain(nc)', SUCCEEDS
		# 'Italy: F Western Mediterranean - Spain(sc)', FAILS

	t 'Coastal issues - A fleet cannot support into an area that is unreachable from its coast',
		'France: F Spain(nc) Supports F Marseilles - Gulf of Lyon', ILLEGAL
		'Italy: F Gulf of Lyon Hold', SUCCEEDS
		'France: F Marseilles - Gulf of Lyon', FAILS

	t 'Coastal issues - Support can be cut from the other coast',
		'England: F Irish Sea Supports F North Atlantic Ocean - Mid-Atlantic Ocean', SUCCEEDS
		'England: F North Atlantic Ocean - Mid-Atlantic Ocean', SUCCEEDS
		'France: F Spain(nc) Supports F Mid-Atlantic Ocean Hold', FAILS
		'France: F Mid-Atlantic Ocean Hold', FAILS
		'Italy: F Gulf of Lyon - Spain(sc)', FAILS

	t 'Coastal issues - Most house rules accept support orders without coast specification',
		'France: F Portugal Supports F Mid-Atlantic Ocean - Spain', SUCCEEDS
		'France: F Mid-Atlantic Ocean - Spain(nc)', FAILS
		'Italy: F Gulf of Lyon Supports F Western Mediterranean - Spain(sc)', SUCCEEDS
		'Italy: F Western Mediterranean - Spain(sc)', FAILS

	# TODO: Double check that 6.B.8 through 6.B.12 are unnecessary

	t 'Coastal issues - Coastal crawl forbidden',
		'Turkey: F Bulgaria(sc) - Constantinople', FAILS
		'Turkey: F Constantinople - Bulgaria(ec)', FAILS

	# TODO: 6.B.14 build order issues

	t 'Circular movement - basic',
		'Turkey: F Ankara - Constantinople', SUCCEEDS
		'Turkey: A Constantinople - Smyrna', SUCCEEDS
		'Turkey: A Smyrna - Ankara', SUCCEEDS

	t 'Circular movement - Three units can change place, even when one gets support',
		'Turkey: F Ankara - Constantinople', SUCCEEDS
		'Turkey: A Constantinople - Smyrna', SUCCEEDS
		'Turkey: A Smyrna - Ankara', SUCCEEDS
		'Turkey: A Bulgaria Supports F Ankara - Constantinople', SUCCEEDS

	t 'Circular movement - One unit bounces, the whole circular movement is blocked',
		'Turkey: F Ankara - Constantinople', FAILS
		'Turkey: A Constantinople - Smyrna', FAILS
		'Turkey: A Smyrna - Ankara', FAILS
		'Turkey: A Bulgaria - Constantinople', FAILS

	t 'Circular movement - Movement contains an attacked convoy, still succeeds',
		'Austria: A Trieste - Serbia', SUCCEEDS
		'Austria: A Serbia - Bulgaria', SUCCEEDS
		'Turkey: A Bulgaria - Trieste', SUCCEEDS
		'Turkey: F Aegean Sea Convoys A Bulgaria - Trieste', SUCCEEDS
		'Turkey: F Ionian Sea Convoys A Bulgaria - Trieste', SUCCEEDS
		'Turkey: F Adriatic Sea Convoys A Bulgaria - Trieste', SUCCEEDS

	t 'Circular movement - Disrupted circular movement due to dislodged convoy',
		'Austria: A Trieste - Serbia', FAILS
		'Austria: A Serbia - Bulgaria', FAILS
		'Turkey: A Bulgaria - Trieste', FAILS
		'Turkey: F Aegean Sea Convoys A Bulgaria - Trieste', SUCCEEDS
		'Turkey: F Ionian Sea Convoys A Bulgaria - Trieste', FAILS
		'Turkey: F Adriatic Sea Convoys A Bulgaria - Trieste', SUCCEEDS
		'Italy: F Naples - Ionian Sea', SUCCEEDS
		'Italy: F Tunis Supports F Naples - Ionian Sea', SUCCEEDS

	t 'Convoy swap - Two armies can swap places even when they are not adjacent.',
		'England: F North Sea Convoys A London - Belgium', SUCCEEDS
		'England: A London - Belgium', SUCCEEDS
		'France: F English Channel Convoys A Belgium - London', SUCCEEDS
		'France: A Belgium - London', SUCCEEDS

	t 'Convoy swap - If in a swap one of the units bounces, then the swap fails',
		'England: F North Sea Convoys A London - Belgium', SUCCEEDS
		'England: A London - Belgium', FAILS
		'France: F English Channel Convoys A Belgium - London', SUCCEEDS
		'France: A Belgium - London', FAILS
		'France: A Burgundy - Belgium', FAILS

	t 'Support to hold - The simplest support to hold order',
		'Austria: F Adriatic Sea Supports A Trieste - Venice', SUCCEEDS
		'Austria: A Trieste - Venice', FAILS
		'Italy: A Venice Hold', SUCCEEDS
		'Italy: A Tyrolia Supports A Venice Hold', SUCCEEDS

	t 'Support to hold - The most simple support on hold cut',
		'Austria: F Adriatic Sea Supports A Trieste - Venice', SUCCEEDS
		'Austria: A Trieste - Venice', SUCCEEDS
		'Austria: A Vienna - Tyrolia', FAILS
		'Italy: A Venice Hold', FAILS
		'Italy: A Tyrolia Supports A Venice Hold', FAILS

	t 'Support on move - The most simple support on move cut',
		'Austria: F Adriatic Sea Supports A Trieste - Venice', FAILS
		'Austria: A Trieste - Venice', FAILS
		'Italy: A Venice Hold', SUCCEEDS
		'Italy: F Ionian Sea - Adriatic Sea', FAILS

	t 'Support hold - A unit that is supporting a hold, can receive a hold support',
		'Germany: A Berlin Supports F Kiel Hold', FAILS
		'Germany: F Kiel Supports A Berlin Hold', SUCCEEDS
		'Russia: A Prussia - Berlin', FAILS
		'Russia: F Baltic Sea Supports A Prussia - Berlin', SUCCEEDS

	t 'Support hold - A unit that is supporting a move, can receive a hold support',
		'Germany: A Berlin Supports A Munich - Silesia', FAILS
		'Germany: F Kiel Supports A Berlin Hold', SUCCEEDS
		'Germany: A Munich - Silesia', SUCCEEDS
		'Russia: F Baltic Sea Supports A Prussia - Berlin', SUCCEEDS
		'Russia: A Prussia - Berlin', FAILS

	t 'Support hold - A unit that is convoying, can receive a hold support',
		'Germany: A Berlin - Sweden', SUCCEEDS
		'Germany: F Baltic Sea Convoys A Berlin - Sweden', SUCCEEDS
		'Germany: F Prussia Supports F Baltic Sea Hold', SUCCEEDS
		'Russia: F Livonia - Baltic Sea', FAILS
		'Russia: F Gulf of Bothnia Supports F Livonia - Baltic Sea', SUCCEEDS

	t 'Support hold - A unit that is moving cannot receive a hold support if the move fails',
		'Germany: F Baltic Sea - Sweden', FAILS
		'Germany: F Prussia Supports F Baltic Sea Hold', ILLEGAL
		'Russia: F Livonia - Baltic Sea', SUCCEEDS
		'Russia: F Gulf of Bothnia Supports F Livonia - Baltic Sea', SUCCEEDS
		'Russia: A Finland - Sweden', FAILS

	t 'Support hold - Failed convoy can not receive hold support',
		'Austria: F Ionian Sea Hold', SUCCEEDS
		'Austria: A Serbia Supports A Albania - Greece', SUCCEEDS
		'Austria: A Albania - Greece', SUCCEEDS
		'Turkey: A Greece - Naples', FAILS
		'Turkey: A Bulgaria Supports A Greece Hold', ILLEGAL

	t 'Hold - A unit that is holding can not receive a support in moving',
		'Italy: A Venice - Trieste', SUCCEEDS
		'Italy: A Tyrolia Supports A Venice - Trieste', SUCCEEDS
		'Austria: A Albania Supports A Trieste - Serbia', SUCCEEDS
		'Austria: A Trieste Hold', FAILS

	# TODO: This may be a bit tricky. - through 6.D.15
	t 'Illegal dislodge - A unit may not dislodge a unit of the same great power',
		'Germany: A Berlin Hold', SUCCEEDS
		'Germany: F Kiel - Berlin', FAILS
		'Germany: A Munich Supports F Kiel - Berlin', SUCCEEDS

	t '6.D.11. No self dislodgment of returning unit',
		'Germany: A Berlin - Prussia', FAILS
		'Germany: F Kiel - Berlin', FAILS
		'Germany: A Munich Supports F Kiel - Berlin', SUCCEEDS
		'Russia: A Warsaw - Prussia', FAILS

	t '6.D.12. Support a foreign unit to dislodge own unit prohibited',
		'Austria: F Trieste Hold', SUCCEEDS
		'Austria: A Vienna Supports A Venice - Trieste', SUCCEEDS
		'Italy: A Venice - Trieste', FAILS

	t '
		6.D.13. Supporting a foreign unit to dislodge returning own
		unit prohibited.
	',
		'Austria: F Trieste - Adriatic Sea', FAILS
		'Austria: A Vienna Supports A Venice - Trieste', SUCCEEDS
		'Italy: A Venice - Trieste', FAILS
		'Italy: F Apulia - Adriatic Sea', FAILS

	t '
		6.D.14. Supporting a foreign unit is not enough to prevent
		dislodgement
	',
		'Austria: F Trieste Hold', FAILS
		'Austria: A Vienna Supports A Venice - Trieste', SUCCEEDS
		'Italy: A Venice - Trieste', SUCCEEDS
		'Italy: A Tyrolia Supports A Venice - Trieste', SUCCEEDS
		'Italy: F Adriatic Sea Supports A Venice - Trieste', SUCCEEDS

	t '6.D.15 Illegal Support Cut - A unit cannot cut support into its own region',
		'Russia: F Constantinople Supports F Black Sea - Ankara', SUCCEEDS
		'Russia: F Black Sea - Ankara', SUCCEEDS
		'Turkey: F Ankara - Constantinople', FAILS

	t 'Convoying a unit dislodging a unit of same power is allowed',
		'England: A London Hold', FAILS
		'England: F North Sea Convoys A Belgium - London', SUCCEEDS
		'France: F English Channel Supports A Belgium - London', SUCCEEDS
		'France: A Belgium - London', SUCCEEDS

	t '6.D.17. Dislodgement cuts supports',
		'Russia: F Constantinople Supports F Black Sea - Ankara', FAILS
		'Russia: F Black Sea - Ankara', FAILS
		'Turkey: F Ankara - Constantinople', SUCCEEDS
		'Turkey: A Smyrna Supports F Ankara - Constantinople', SUCCEEDS
		'Turkey: A Armenia - Ankara', FAILS

	t '6.D.18. A surviving unit will sustain support',
		'Russia: F Constantinople Supports F Black Sea - Ankara', SUCCEEDS
		'Russia: F Black Sea - Ankara', SUCCEEDS
		'Russia: A Bulgaria Supports F Constantinople Hold', SUCCEEDS
		'Turkey: F Ankara - Constantinople', FAILS
		'Turkey: A Smyrna Supports F Ankara - Constantinople', SUCCEEDS
		'Turkey: A Armenia - Ankara', FAILS

	t '6.D.19. Even when surviving is in alternative way',
		'Russia: F Constantinople Supports F Black Sea - Ankara', SUCCEEDS
		'Russia: F Black Sea - Ankara', SUCCEEDS
		'Russia: A Smyrna Supports F Ankara - Constantinople', SUCCEEDS
		'Turkey: F Ankara - Constantinople', FAILS

	t '6.D.20. Unit can not cut support of its own country',
		'England: F London Supports F North Sea - English Channel', SUCCEEDS
		'England: F North Sea - English Channel', SUCCEEDS
		'England: A Yorkshire - London', FAILS
		'France: F English Channel Hold', FAILS

	t '6.D.21. Dislodging does not cancel a support cut',
		'Austria: F Trieste Hold', SUCCEEDS
		'Italy: A Venice - Trieste', FAILS
		'Italy: A Tyrolia Supports A Venice - Trieste', FAILS
		'Germany: A Munich - Tyrolia', FAILS
		'Russia: A Silesia - Munich', SUCCEEDS
		'Russia: A Berlin Supports A Silesia - Munich', SUCCEEDS

	t '6.D.22. Impossible fleet move can not be supported',
		'Germany: F Kiel - Munich', FAILS
		'Germany: A Burgundy Supports F Kiel - Munich', SUCCEEDS
		'Russia: A Munich - Kiel', SUCCEEDS
		'Russia: A Berlin Supports A Munich - Kiel', SUCCEEDS

	t '6.D.23. Impossible coast move can not be supported',
		'Italy: F Gulf of Lyon - Spain(sc)', SUCCEEDS
		'Italy: F Western Mediterranean Supports F Gulf of Lyon - Spain(sc)', SUCCEEDS
		'France: F Spain(nc) - Gulf of Lyon', FAILS
		'France: F Marseilles Supports F Spain(nc) - Gulf of Lyon', SUCCEEDS

	t '6.D.24. Impossible army move can not be supported',
		'France: A Marseilles - Gulf of Lyon', FAILS
		'France: F Spain(sc) Supports A Marseilles - Gulf of Lyon', ILLEGAL
		'Italy: F Gulf of Lyon Hold', FAILS
		'Turkey: F Western Mediterranean - Gulf of Lyon', SUCCEEDS
		'Turkey: F Tyrrhenian Sea Supports F Western Mediterranean - Gulf of Lyon', SUCCEEDS

	t '6.D.25. Failing hold support can be supported',
		'Germany: A Berlin Supports A Prussia Hold', ILLEGAL
		'Germany: F Kiel Supports A Berlin Hold', SUCCEEDS
		'Russia: F Baltic Sea Supports A Prussia - Berlin', SUCCEEDS
		'Russia: A Prussia - Berlin', FAILS

	t '6.D.26. Failing move support can be supported',
		'Germany: A Berlin Supports A Prussia - Silesia', FAILS
		'Germany: F Kiel Supports A Berlin Hold', SUCCEEDS
		'Russia: F Baltic Sea Supports A Prussia - Berlin', SUCCEEDS
		'Russia: A Prussia - Berlin', FAILS

	t '6.D.27. Failing convoy can be supported',
		'England: F Sweden - Baltic Sea', FAILS
		'England: F Denmark Supports F Sweden - Baltic Sea', SUCCEEDS
		'Germany: A Berlin Hold', SUCCEEDS
		'Russia: F Baltic Sea Convoys A Berlin - Livonia', SUCCEEDS
		'Russia: F Prussia Supports F Baltic Sea Hold', SUCCEEDS

	# TODO: This test case is failing according to preferences but technically
	# still correct and consistent. Special handling could make it a little
	# more user friendly as suggested in the DATC cases. 6.D.29 and 30 are
	# similar kinds of things.
	t '6.D.28. Impossible move and support',
		'Austria: A Budapest Supports F Rumania Hold', ILLEGAL
		'Russia: F Rumania - Holland', FAILS
		'Turkey: F Black Sea - Rumania', SUCCEEDS
		'Turkey: A Bulgaria Supports F Black Sea - Rumania', SUCCEEDS

	# TODO: This may deserve more attention but it's another one of those
	# things where it has to do with determining which orders should be
	# considred illegal and thrown out rather than the correctness of the
	# adjudicator itself.
	t '6.D.31. A tricky impossible support',
		'Austria: A Rumania - Armenia', FAILS
		'Turkey: F Black Sea Supports A Rumania - Armenia', SUCCEEDS

	t '6.D.33. Unwanted support allowed',
		'Austria: A Serbia - Budapest', SUCCEEDS
		'Austria: A Vienna - Budapest', FAILS
		'Russia: A Galicia Supports A Serbia - Budapest', SUCCEEDS
		'Turkey: A Bulgaria - Serbia', SUCCEEDS

	t '6.D.34. Support targeting own area not allowed',
		'Germany: A Berlin - Prussia', SUCCEEDS
		'Germany: A Silesia Supports A Berlin - Prussia', SUCCEEDS
		'Germany: F Baltic Sea Supports A Berlin - Prussia', SUCCEEDS
		'Italy: A Prussia Supports A Livonia - Prussia', ILLEGAL
		'Russia: A Warsaw Supports A Livonia - Prussia', SUCCEEDS
		'Russia: A Livonia - Prussia', FAILS

	t '6.E.1. Dislodged unit has no effect on attackers area',
		'Germany: A Berlin - Prussia', SUCCEEDS
		'Germany: F Kiel - Berlin', SUCCEEDS
		'Germany: A Silesia Supports A Berlin - Prussia', SUCCEEDS
		'Russia: A Prussia - Berlin', FAILS

	t '6.E.2. No self dislodgement in head to head battle',
		'Germany: A Berlin - Kiel', FAILS
		'Germany: F Kiel - Berlin', FAILS
		'Germany: A Munich Supports A Berlin - Kiel', SUCCEEDS

	t '6.E.3. No help in dislodging own unit',
		'Germany: A Berlin - Kiel', FAILS
		'Germany: A Munich Supports F Kiel - Berlin', SUCCEEDS
		'England: F Kiel - Berlin', FAILS

	t '6.E.4. Non-dislodged loser has still effect',
		'Germany: F Holland - North Sea', FAILS
		'Germany: F Helgoland Bight Supports F Holland - North Sea', SUCCEEDS
		'Germany: F Skagerrak Supports F Holland - North Sea', SUCCEEDS
		'France: F North Sea - Holland', FAILS
		'France: F Belgium Supports F North Sea - Holland', SUCCEEDS
		'England: F Edinburgh Supports F Norwegian Sea - North Sea', SUCCEEDS
		'England: F Yorkshire Supports F Norwegian Sea - North Sea', SUCCEEDS
		'England: F Norwegian Sea - North Sea', FAILS
		'Austria: A Kiel Supports A Ruhr - Holland', SUCCEEDS
		'Austria: A Ruhr - Holland', FAILS

	t '6.E.5. Loser dislodged by another army has still effect',
		'Germany: F Holland - North Sea', FAILS
		'Germany: F Helgoland Bight Supports F Holland - North Sea', SUCCEEDS
		'Germany: F Skagerrak Supports F Holland - North Sea', SUCCEEDS
		'France: F North Sea - Holland', FAILS
		'France: F Belgium Supports F North Sea - Holland', SUCCEEDS
		'England: F Edinburgh Supports F Norwegian Sea - North Sea', SUCCEEDS
		'England: F Yorkshire Supports F Norwegian Sea - North Sea', SUCCEEDS
		'England: F Norwegian Sea - North Sea', SUCCEEDS
		'England: F London Supports F Norwegian Sea - North Sea', SUCCEEDS
		'Austria: A Kiel Supports A Ruhr - Holland', SUCCEEDS
		'Austria: A Ruhr - Holland', FAILS

	t '6.E.6. Not dislodge because of own support has still effect',
		'Germany: F Holland - North Sea', FAILS
		'Germany: F Helgoland Bight Supports F Holland - North Sea', SUCCEEDS
		'France: F North Sea - Holland', FAILS
		'France: F Belgium Supports F North Sea - Holland', SUCCEEDS
		'France: F English Channel Supports F Holland - North Sea', SUCCEEDS
		'Austria: A Kiel Supports A Ruhr - Holland', SUCCEEDS
		'Austria: A Ruhr - Holland', FAILS

	t '6.E.7. No self dislodgement with beleaguered garrison',
		'England: F North Sea Hold', SUCCEEDS
		'England: F Yorkshire Supports F Norway - North Sea', SUCCEEDS
		'Germany: F Holland Supports F Helgoland Bight - North Sea', SUCCEEDS
		'Germany: F Helgoland Bight - North Sea', FAILS
		'Russia: F Skagerrak Supports F Norway - North Sea', SUCCEEDS
		'Russia: F Norway - North Sea', FAILS

	t '6.E.8. Test case, no self dislodgement with beleaguered garrison and head to head battle',
		'England: F North Sea - Norway', FAILS
		'England: F Yorkshire Supports F Norway - North Sea', SUCCEEDS
		'Germany: F Holland Supports F Helgoland Bight - North Sea', SUCCEEDS
		'Germany: F Helgoland Bight - North Sea', FAILS
		'Russia: F Skagerrak Supports F Norway - North Sea', SUCCEEDS
		'Russia: F Norway - North Sea', FAILS

	t '6.E.9. Almost self dislodgement with beleaguered garrison',
		'England: F North Sea - Norwegian Sea', SUCCEEDS
		'England: F Yorkshire Supports F Norway - North Sea', SUCCEEDS
		'Germany: F Helgoland Bight - North Sea', FAILS
		'Germany: F Holland Supports F Helgoland Bight - North Sea', SUCCEEDS
		'Russia: F Norway - North Sea', SUCCEEDS
		'Russia: F Skagerrak Supports F Norway - North Sea', SUCCEEDS

	t '6.E.10. Almost circular movement with no self dislodgement with beleaguered garrison',
		'England: F North Sea - Denmark', FAILS
		'England: F Yorkshire Supports F Norway - North Sea', SUCCEEDS
		'Germany: F Holland Supports F Helgoland Bight - North Sea', SUCCEEDS
		'Germany: F Helgoland Bight - North Sea', FAILS
		'Germany: F Denmark - Helgoland Bight', FAILS
		'Russia: F Skagerrak Supports F Norway - North Sea', SUCCEEDS
		'Russia: F Norway - North Sea', FAILS

	# TODO: via convoy
	# t '
	# 	6.E.11. No self dislodgement with beleaguered garrison, unit swap with
	# 	adjacent convoying and two coasts
	# '

# Similar to the previous test case, but now the beleaguered fleet is in a unit swap with the
# stronger attacker. So, the unit swap succeeds. To make the situation more complex, the swap is
# on an area with two coasts.
	# 	'France: A Spain - Portugal via Convoy'
	# 	'France: F Mid-Atlantic Ocean Convoys A Spain - Portugal'
	# 	'France: F Gulf of Lyon Supports F Portugal - Spain(nc)'
	# 	'Germany: A Marseilles Supports A Gascony - Spain'
	# 	'Germany: A Gascony - Spain'
	# 	'Italy: F Portugal - Spain(nc)'
	# 	'Italy: F Western Mediterranean Supports F Portugal - Spain(nc)'
# The unit swap succeeds. Note that due to the success of the swap, there is no beleaguered
# garrison anymore.

	t '6.E.12. Support on attack on own unit can be used for other means',
		'Austria: A Budapest - Rumania', FAILS
		'Austria: A Serbia Supports A Vienna - Budapest', SUCCEEDS
		'Italy: A Vienna - Budapest', FAILS
		'Russia: A Galicia - Budapest', FAILS
		'Russia: A Rumania Supports A Galicia - Budapest', SUCCEEDS

	t '6.E.13. Three way beleaguered garrison',
		'England: F Edinburgh Supports F Yorkshire - North Sea', SUCCEEDS
		'England: F Yorkshire - North Sea', FAILS
		'France: F Belgium - North Sea', FAILS
		'France: F English Channel Supports F Belgium - North Sea', SUCCEEDS
		'Germany: F North Sea Hold', SUCCEEDS
		'Russia: F Norwegian Sea - North Sea', FAILS
		'Russia: F Norway Supports F Norwegian Sea - North Sea', SUCCEEDS

	t '6.E.14. Illegal head to head battle can still defend',
		'England: A Liverpool - Edinburgh', FAILS
		'Russia: F Edinburgh - Liverpool', FAILS

	t '6.E.15. The friendly head to head battle',
		'England: F Holland Supports A Ruhr - Kiel', SUCCEEDS
		'England: A Ruhr - Kiel', FAILS
		'France: A Kiel - Berlin', FAILS
		'France: A Munich Supports A Kiel - Berlin', SUCCEEDS
		'France: A Silesia Supports A Kiel - Berlin', SUCCEEDS
		'Germany: A Berlin - Kiel', FAILS
		'Germany: F Denmark Supports A Berlin - Kiel', SUCCEEDS
		'Germany: F Helgoland Bight Supports A Berlin - Kiel', SUCCEEDS
		'Russia: F Baltic Sea Supports A Prussia - Berlin', SUCCEEDS
		'Russia: A Prussia - Berlin', FAILS

	t '6.F.1. No convoy in coastal areas',
		'Turkey: A Greece - Sevastopol', FAILS
		'Turkey: F Aegean Sea Convoys A Greece - Sevastopol', SUCCEEDS
		# TODO: This should probably come back as ILLEGAL although it's
		# handled correctly by hasPath so there's no tangible impact
		'Turkey: F Constantinople Convoys A Greece - Sevastopol', SUCCEEDS
		'Turkey: F Black Sea Convoys A Greece - Sevastopol', SUCCEEDS

	t '6.F.2. An army being convoyed can bounce as normal',
		'England: F English Channel Convoys A London - Brest', SUCCEEDS
		'England: A London - Brest', FAILS
		'France: A Paris - Brest', FAILS

	t '6.F.3. An army being convoyed can receive support',
		'England: F English Channel Convoys A London - Brest', SUCCEEDS
		'England: A London - Brest', SUCCEEDS
		'England: F Mid-Atlantic Ocean Supports A London - Brest', SUCCEEDS
		'France: A Paris - Brest', FAILS

	t '6.F.4. An attacked convoy is not disrupted',
		'England: F North Sea Convoys A London - Holland', SUCCEEDS
		'England: A London - Holland', SUCCEEDS
		'Germany: F Skagerrak - North Sea', FAILS

	t '6.F.5. A beleaguered convoy is not disrupted',
		'England: F North Sea Convoys A London - Holland', SUCCEEDS
		'England: A London - Holland', SUCCEEDS
		'France: F English Channel - North Sea', FAILS
		'France: F Belgium Supports F English Channel - North Sea', SUCCEEDS
		'Germany: F Skagerrak - North Sea', FAILS
		'Germany: F Denmark Supports F Skagerrak - North Sea', SUCCEEDS

	t '6.F.6. Dislodged convoy does not cut support',
		'England: F North Sea Convoys A London - Holland', FAILS
		'England: A London - Holland', FAILS
		'Germany: A Holland Supports A Belgium Hold', SUCCEEDS
		'Germany: A Belgium Supports A Holland Hold', FAILS
		'Germany: F Helgoland Bight Supports F Skagerrak - North Sea', SUCCEEDS
		'Germany: F Skagerrak - North Sea', SUCCEEDS
		'France: A Picardy - Belgium', FAILS
		'France: A Burgundy Supports A Picardy - Belgium', SUCCEEDS

	# TODO: Retreats - Dislodged English fleet can retreat to Holland
	# t '6.F.7. Dislodged convoy does not cause contested area',
	# 	'England: F North Sea Convoys A London - Holland'
	# 	'England: A London - Holland'
	# 	'Germany: F Helgoland Bight Supports F Skagerrak - North Sea'
	# 	'Germany: F Skagerrak - North Sea'

	t '6.F.8. Dislodged convoy does not cause a bounce',
		'England: F North Sea Convoys A London - Holland', FAILS
		'England: A London - Holland', FAILS
		'Germany: F Helgoland Bight Supports F Skagerrak - North Sea', SUCCEEDS
		'Germany: F Skagerrak - North Sea', SUCCEEDS
		'Germany: A Belgium - Holland', SUCCEEDS

	t '6.F.9. Dislodge of multi-route convoy',
		'England: F English Channel Convoys A London - Belgium', FAILS
		'England: F North Sea Convoys A London - Belgium', SUCCEEDS
		'England: A London - Belgium', SUCCEEDS
		'France: F Brest Supports F Mid-Atlantic Ocean - English Channel', SUCCEEDS
		'France: F Mid-Atlantic Ocean - English Channel', SUCCEEDS

	t '6.F.10. Dislodge of multi-route convoy with foreign fleet',
		'England: F North Sea Convoys A London - Belgium', SUCCEEDS
		'England: A London - Belgium', SUCCEEDS
		'Germany: F English Channel Convoys A London - Belgium', FAILS
		'France: F Brest Supports F Mid-Atlantic Ocean - English Channel', SUCCEEDS
		'France: F Mid-Atlantic Ocean - English Channel', SUCCEEDS

	t '6.F.11. Dislodge of multi-route convoy with only foreign fleets',
		'England: A London - Belgium', SUCCEEDS
		'Germany: F English Channel Convoys A London - Belgium', FAILS
		'Russia: F North Sea Convoys A London - Belgium', SUCCEEDS
		'France: F Brest Supports F Mid-Atlantic Ocean - English Channel', SUCCEEDS
		'France: F Mid-Atlantic Ocean - English Channel', SUCCEEDS

	t '6.F.12. Dislodged convoying fleet not on route',
		'England: F English Channel Convoys A London - Belgium', SUCCEEDS
		'England: A London - Belgium', SUCCEEDS
		'England: F Irish Sea Convoys A London - Belgium', FAILS
		'France: F North Atlantic Ocean Supports F Mid-Atlantic Ocean - Irish Sea', SUCCEEDS
		'France: F Mid-Atlantic Ocean - Irish Sea', SUCCEEDS

	t '6.F.13. The unwanted alternative',
		'England: A London - Belgium', SUCCEEDS
		'England: F North Sea Convoys A London - Belgium', FAILS
		'France: F English Channel Convoys A London - Belgium', SUCCEEDS
		'Germany: F Holland Supports F Denmark - North Sea', SUCCEEDS
		'Germany: F Denmark - North Sea', SUCCEEDS

	t '6.F.14. Simple convoy paradox',
		'England: F London Supports F Wales - English Channel', SUCCEEDS
		'England: F Wales - English Channel', SUCCEEDS
		'France: A Brest - London', FAILS
		'France: F English Channel Convoys A Brest - London', FAILS

	t '6.F.15. Simple convoy paradox with additional convoy',
		'England: F London Supports F Wales - English Channel', SUCCEEDS
		'England: F Wales - English Channel', SUCCEEDS
		'France: A Brest - London', FAILS
		'France: F English Channel Convoys A Brest - London', FAILS
		'Italy: F Irish Sea Convoys A North Africa - Wales', SUCCEEDS
		'Italy: F Mid-Atlantic Ocean Convoys A North Africa - Wales', SUCCEEDS
		'Italy: A North Africa - Wales', SUCCEEDS

	t '6.F.16. Pandin\'s paradox',
		'England: F London Supports F Wales - English Channel', SUCCEEDS
		'England: F Wales - English Channel', FAILS
		'France: A Brest - London', FAILS
		'France: F English Channel Convoys A Brest - London', FAILS
		'Germany: F North Sea Supports F Belgium - English Channel', SUCCEEDS
		'Germany: F Belgium - English Channel', FAILS

	t '6.F.17. Pandin\'s extended paradox',
		'England: F London Supports F Wales - English Channel', SUCCEEDS
		'England: F Wales - English Channel', FAILS
		'France: A Brest - London', FAILS
		'France: F English Channel Convoys A Brest - London', FAILS
		'France: F Yorkshire Supports A Brest - London', SUCCEEDS
		'Germany: F North Sea Supports F Belgium - English Channel', SUCCEEDS
		'Germany: F Belgium - English Channel', FAILS

	t '6.F.18 Betrayl paradox',
		'England: F North Sea Convoys A London - Belgium', FAILS
		'England: A London - Belgium', FAILS
		'England: F English Channel Supports A London - Belgium', SUCCEEDS
		'France: F Belgium Supports F North Sea Hold', SUCCEEDS
		'Germany: F Helgoland Bight Supports F Skagerrak - North Sea', SUCCEEDS
		'Germany: F Skagerrak - North Sea', FAILS

	t '6.F.19. Multi-route convoy disruption paradox',
		'France: A Tunis - Naples', FAILS
		'France: F Tyrrhenian Sea Convoys A Tunis - Naples', SUCCEEDS
		'France: F Ionian Sea Convoys A Tunis - Naples', SUCCEEDS
		'Italy: F Naples Supports F Rome - Tyrrhenian Sea', FAILS
		'Italy: F Rome - Tyrrhenian Sea', FAILS

	t '6.F.20. Unwanted multi-route convoy paradox',
		'France: A Tunis - Naples', FAILS
		'France: F Tyrrhenian Sea Convoys A Tunis - Naples', SUCCEEDS
		'Italy: F Naples Supports F Ionian Sea Hold', FAILS
		'Italy: F Ionian Sea Convoys A Tunis - Naples', FAILS
		'Turkey: F Aegean Sea Supports F Eastern Mediterranean - Ionian Sea', SUCCEEDS
		'Turkey: F Eastern Mediterranean - Ionian Sea', SUCCEEDS

	t '6.F.21. Dad\'s army convoy',
		'Russia: A Edinburgh Supports A Norway - Clyde', SUCCEEDS
		'Russia: F Norwegian Sea Convoys A Norway - Clyde', SUCCEEDS
		'Russia: A Norway - Clyde', SUCCEEDS
		'France: F Irish Sea Supports F Mid-Atlantic Ocean - North Atlantic Ocean', SUCCEEDS
		'France: F Mid-Atlantic Ocean - North Atlantic Ocean', SUCCEEDS
		'England: A Liverpool - Clyde', FAILS
		'England: F North Atlantic Ocean Convoys A Liverpool - Clyde', FAILS
		'England: F Clyde Supports F North Atlantic Ocean Hold', FAILS

	t '6.F.22. Second order paradox with two resolutions',
		'England: F Edinburgh - North Sea', SUCCEEDS
		'England: F London Supports F Edinburgh - North Sea', SUCCEEDS
		'France: A Brest - London', FAILS
		'France: F English Channel Convoys A Brest - London', FAILS
		'Germany: F Belgium Supports F Picardy - English Channel', SUCCEEDS
		'Germany: F Picardy - English Channel', SUCCEEDS
		'Russia: A Norway - Belgium', FAILS
		'Russia: F North Sea Convoys A Norway - Belgium', FAILS

	t '6.F.23. Second order paradox with two exclusive convoys',
		'England: F Edinburgh - North Sea', FAILS
		'England: F Yorkshire Supports F Edinburgh - North Sea', SUCCEEDS
		'France: A Brest - London', FAILS
		'France: F English Channel Convoys A Brest - London', FAILS
		'Germany: F Belgium Supports F English Channel Hold', SUCCEEDS
		'Germany: F London Supports F North Sea Hold', SUCCEEDS
		'Italy: F Mid-Atlantic Ocean - English Channel', FAILS
		'Italy: F Irish Sea Supports F Mid-Atlantic Ocean - English Channel', SUCCEEDS
		'Russia: A Norway - Belgium', FAILS
		'Russia: F North Sea Convoys A Norway - Belgium', FAILS

	t '6.F.24. Second order paradox with no resolution',
		'England: F Edinburgh - North Sea', SUCCEEDS
		'England: F London Supports F Edinburgh - North Sea', SUCCEEDS
		'England: F Irish Sea - English Channel', FAILS
		'England: F Mid-Atlantic Ocean Supports F Irish Sea - English Channel', SUCCEEDS
		'France: A Brest - London', FAILS
		'France: F English Channel Convoys A Brest - London', FAILS
		'France: F Belgium Supports F English Channel Hold', SUCCEEDS
		'Russia: A Norway - Belgium', FAILS
		'Russia: F North Sea Convoys A Norway - Belgium', FAILS

	t '6.G.1. Two units can swap places by convoy',
		'England: A Norway - Sweden', SUCCEEDS
		'England: F Skagerrak Convoys A Norway - Sweden', SUCCEEDS
		'Russia: A Sweden - Norway', SUCCEEDS

	t '6.G.2. Kidnapping an army',
		'England: A Norway - Sweden', FAILS
		'Russia: F Sweden - Norway', FAILS
		'Germany: F Skagerrak Convoys A Norway - Sweden', SUCCEEDS

	t '6.G.3. Kidnapping with a disrupted convoy',
		'France: F Brest - English Channel', SUCCEEDS
		'France: A Picardy - Belgium', SUCCEEDS
		'France: A Burgundy Supports A Picardy - Belgium', SUCCEEDS
		'France: F Mid-Atlantic Ocean Supports F Brest - English Channel', SUCCEEDS
		'England: F English Channel Convoys A Picardy - Belgium', FAILS

	t '6.G.4. Kidnapping with a disrupted convoy and opposite move',
		'France: F Brest - English Channel', SUCCEEDS
		'France: A Picardy - Belgium', SUCCEEDS
		'France: A Burgundy Supports A Picardy - Belgium', SUCCEEDS
		'France: F Mid-Atlantic Ocean Supports F Brest - English Channel', SUCCEEDS
		'England: F English Channel Convoys A Picardy - Belgium', FAILS
		'England: A Belgium - Picardy', FAILS

	t '6.G.5. Swapping with intent',
		'Italy: A Rome - Apulia', SUCCEEDS
		'Italy: F Tyrrhenian Sea Convoys A Apulia - Rome', SUCCEEDS
		'Turkey: A Apulia - Rome', SUCCEEDS
		'Turkey: F Ionian Sea Convoys A Apulia - Rome', SUCCEEDS

	t '6.G.6. Swapping with unintended intent',
		'England: A Liverpool - Edinburgh', SUCCEEDS
		'England: F English Channel Convoys A Liverpool - Edinburgh', SUCCEEDS
		'Germany: A Edinburgh - Liverpool', SUCCEEDS
		'France: F Irish Sea Hold', SUCCEEDS
		'France: F North Sea Hold', SUCCEEDS
		'Russia: F Norwegian Sea Convoys A Liverpool - Edinburgh', SUCCEEDS
		'Russia: F North Atlantic Ocean Convoys A Liverpool - Edinburgh', SUCCEEDS

	t '6.G.7. Swapping with illegal intent',
		'England: F Skagerrak Convoys A Sweden - Norway', SUCCEEDS
		'England: F Norway - Sweden', SUCCEEDS
		'Russia: A Sweden - Norway', SUCCEEDS
		'Russia: F Gulf of Bothnia Convoys A Sweden - Norway', SUCCEEDS

	t '6.G.8. Explicit convoy that isn\'t there',
		'France: A Belgium - Holland via Convoy', FAILS
		'England: F North Sea - Helgoland Bight', SUCCEEDS
		'England: A Holland - Kiel', SUCCEEDS

	t '6.G.9. Swapped or dislodged?',
		'England: A Norway - Sweden', SUCCEEDS
		'England: F Skagerrak Convoys A Norway - Sweden', SUCCEEDS
		'England: F Finland Supports A Norway - Sweden', SUCCEEDS
		'Russia: A Sweden - Norway', SUCCEEDS

	t '6.G.10. Swapped or an head to head battle?',
		'England: A Norway - Sweden via Convoy', SUCCEEDS
		'England: F Denmark Supports A Norway - Sweden', SUCCEEDS
		'England: F Finland Supports A Norway - Sweden', SUCCEEDS
		'Germany: F Skagerrak Convoys A Norway - Sweden', SUCCEEDS
		'Russia: A Sweden - Norway', FAILS
		'Russia: F Barents Sea Supports A Sweden - Norway', SUCCEEDS
		'France: F Norwegian Sea - Norway', FAILS
		'France: F North Sea Supports F Norwegian Sea - Norway', SUCCEEDS

	t '6.G.11. A convoy to an adjacent place with a paradox',
		'England: F Norway Supports F North Sea - Skagerrak', SUCCEEDS
		'England: F North Sea - Skagerrak', SUCCEEDS
		'Russia: A Sweden - Norway', FAILS
		'Russia: F Skagerrak Convoys A Sweden - Norway', FAILS
		'Russia: F Barents Sea Supports A Sweden - Norway', SUCCEEDS

	t '6.G.12. Swapping two units with two convoys',
		'England: A Liverpool - Edinburgh via Convoy', SUCCEEDS
		'England: F North Atlantic Ocean Convoys A Liverpool - Edinburgh', SUCCEEDS
		'England: F Norwegian Sea Convoys A Liverpool - Edinburgh', SUCCEEDS
		'Germany: A Edinburgh - Liverpool via Convoy', SUCCEEDS
		'Germany: F North Sea Convoys A Edinburgh - Liverpool', SUCCEEDS
		'Germany: F English Channel Convoys A Edinburgh - Liverpool', SUCCEEDS
		'Germany: F Irish Sea Convoys A Edinburgh - Liverpool', SUCCEEDS

	# TODO: Public opinion?
	t '6.G.13. Support cut on attack on itself via convoy',
		'Austria: F Adriatic Sea Convoys A Trieste - Venice', SUCCEEDS
		'Austria: A Trieste - Venice via Convoy', FAILS
		'Italy: A Venice Supports F Albania - Trieste', SUCCEEDS
		'Italy: F Albania - Trieste', SUCCEEDS

	t '6.G.14. Bounce by convoy to adjacent place',
		'England: A Norway - Sweden', SUCCEEDS
		'England: F Denmark Supports A Norway - Sweden', SUCCEEDS
		'England: F Finland Supports A Norway - Sweden', SUCCEEDS
		'France: F Norwegian Sea - Norway', FAILS
		'France: F North Sea Supports F Norwegian Sea - Norway', SUCCEEDS
		'Germany: F Skagerrak Convoys A Sweden - Norway', SUCCEEDS
		'Russia: A Sweden - Norway via Convoy', FAILS
		'Russia: F Barents Sea Supports A Sweden - Norway', SUCCEEDS

	t '6.G.15. Bounce and dislodge with double convoy',
		'England: F North Sea Convoys A London - Belgium', SUCCEEDS
		'England: A Holland Supports A London - Belgium', SUCCEEDS
		'England: A Yorkshire - London', FAILS
		'England: A London - Belgium via Convoy', SUCCEEDS
		'France: F English Channel Convoys A Belgium - London', SUCCEEDS
		'France: A Belgium - London via Convoy', FAILS

	t '6.G.16. The two unit in one area bug, moving by convoy',
		'England: A Norway - Sweden', SUCCEEDS
		'England: A Denmark Supports A Norway - Sweden', SUCCEEDS
		'England: F Baltic Sea Supports A Norway - Sweden', SUCCEEDS
		'England: F North Sea - Norway', FAILS
		'Russia: A Sweden - Norway via Convoy', SUCCEEDS
		'Russia: F Skagerrak Convoys A Sweden - Norway', SUCCEEDS
		'Russia: F Norwegian Sea Supports A Sweden - Norway', SUCCEEDS

	t '6.G.17. The two unit in one area bug, moving over land',
		'England: A Norway - Sweden via Convoy', SUCCEEDS
		'England: A Denmark Supports A Norway - Sweden', SUCCEEDS
		'England: F Baltic Sea Supports A Norway - Sweden', SUCCEEDS
		'England: F Skagerrak Convoys A Norway - Sweden', SUCCEEDS
		'England: F North Sea - Norway', FAILS
		'Russia: A Sweden - Norway', SUCCEEDS
		'Russia: F Norwegian Sea Supports A Sweden - Norway', SUCCEEDS

	t '6.G.18. The two unit in one area bug, with double convoy',
		'England: F North Sea Convoys A London - Belgium', SUCCEEDS
		'England: A Holland Supports A London - Belgium', SUCCEEDS
		'England: A Yorkshire - London', FAILS
		'England: A London - Belgium', SUCCEEDS
		'England: A Ruhr Supports A London - Belgium', SUCCEEDS
		'France: F English Channel Convoys A Belgium - London', SUCCEEDS
		'France: A Belgium - London', SUCCEEDS
		'France: A Wales Supports A Belgium - London', SUCCEEDS

	console.log "Testing Retreats"
	console.log "----------------"

	r '6.H.1. No supports during retreat',
		moves: [
			'Austria: F Trieste Hold'
			'Austria: A Serbia Hold'
			'Turkey: F Greece Hold'
			'Italy: A Venice Supports A Tyrolia - Trieste'
			'Italy: A Tyrolia - Trieste'
			'Italy: F Ionian Sea - Greece'
			'Italy: F Aegean Sea Supports F Ionian Sea - Greece'
		]
		retreats: [
			'Austria: F Trieste - Albania', FAILS
			'Austria: A Serbia Supports F Trieste - Albania', FAILS
			'Turkey: F Greece - Albania', FAILS
		]

	r '6.H.2. No supports from retreating unit',
		moves: [
			'England: A Liverpool - Edinburgh'
			'England: F Yorkshire Supports A Liverpool - Edinburgh'
			'England: F Norway Hold'
			'Germany: A Kiel Supports A Ruhr - Holland'
			'Germany: A Ruhr - Holland'
			'Russia: F Edinburgh Hold'
			'Russia: A Sweden Supports A Finland - Norway'
			'Russia: A Finland - Norway'
			'Russia: F Holland Hold'
		]
		retreats: [
			'England: F Norway - North Sea', FAILS
			'Russia: F Edinburgh - North Sea', FAILS
			'Russia: F Holland Supports F Edinburgh - North Sea', FAILS
		]

	r '6.H.3. No convoy during retreat',
		moves: [
			'England: F North Sea Hold'
			'England: A Holland Hold'
			'Germany: F Kiel Supports A Ruhr - Holland'
			'Germany: A Ruhr - Holland'
		]
		retreats: [
			'England: A Holland - Yorkshire', FAILS
			'England: F North Sea Convoys A Holland - Yorkshire', FAILS
		]

	r '6.H.4. No other moves during retreat',
		moves: [
			'England: F North Sea Hold'
			'England: A Holland Hold'
			'Germany: F Kiel Supports A Ruhr - Holland'
			'Germany: A Ruhr - Holland'
		]
		retreats: [
			'England: A Holland - Belgium', SUCCEEDS
			'England: F North Sea - Norwegian Sea', FAILS
		]

	r '6.H.5. A unit may not retreat to the area from which it is attacked',
		moves: [
			'Russia: F Constantinople Supports F Black Sea - Ankara'
			'Russia: F Black Sea - Ankara'
			'Turkey: F Ankara Hold'
		]
		retreats: [
			'Turkey: F Ankara - Black Sea', FAILS
		]

	r '6.H.6. Unit may not retreat to a contested area',
		moves: [
			'Austria: A Budapest Supports A Trieste - Vienna'
			'Austria: A Trieste - Vienna'
			'Germany: A Munich - Bohemia'
			'Germany: A Silesia - Bohemia'
			'Italy: A Vienna Hold'
		]
		retreats: [
			'Italy: A Vienna - Bohemia', FAILS
		]

	r '6.H.7. Multiple retreat to same area will disband units',
		moves: [
			'Austria: A Budapest Supports A Trieste - Vienna'
			'Austria: A Trieste - Vienna'
			'Germany: A Munich Supports A Silesia - Bohemia'
			'Germany: A Silesia - Bohemia'
			'Italy: A Vienna Hold'
			'Italy: A Bohemia Hold'
		]
		retreats: [
			'Italy: A Bohemia - Tyrolia', FAILS
			'Italy: A Vienna - Tyrolia', FAILS
		]

	r '6.H.8. Triple retreat to same area will disband units',
		moves: [
			'England: A Liverpool - Edinburgh'
			'England: F Yorkshire Supports A Liverpool - Edinburgh'
			'England: F Norway Hold'
			'Germany: A Kiel Supports A Ruhr - Holland'
			'Germany: A Ruhr - Holland'
			'Russia: F Edinburgh Hold'
			'Russia: A Sweden Supports A Finland - Norway'
			'Russia: A Finland - Norway'
			'Russia: F Holland Hold'
		]
		retreats: [
			'England: F Norway - North Sea', FAILS
			'Russia: F Edinburgh - North Sea', FAILS
			'Russia: F Holland - North Sea', FAILS
		]

	r '6.H.9. Dislodged unit will not make attackers area contested',
		moves: [
			'England: F Helgoland Bight - Kiel'
			'England: F Denmark Supports F Helgoland Bight - Kiel'
			'Germany: A Berlin - Prussia'
			'Germany: F Kiel Hold'
			'Germany: A Silesia Supports A Berlin - Prussia'
			'Russia: A Prussia - Berlin'
		]
		retreats: [
			'Germany: F Kiel - Berlin', SUCCEEDS
		]

	r '6.H.10. Not retreating to attacker does not mean contested',
		moves: [
			'England: A Kiel Hold'
			'Germany: A Berlin - Kiel'
			'Germany: A Munich Supports A Berlin - Kiel'
			'Germany: A Prussia Hold'
			'Russia: A Warsaw - Prussia'
			'Russia: A Silesia Supports A Warsaw - Prussia'
		]
		retreats: [
			'England: A Kiel - Berlin', FAILS
			'Germany: A Prussia - Berlin', SUCCEEDS
		]

	r '6.H.11. Retreat when dislodged by adjacent convoy',
		moves: [
			'France: A Gascony - Marseilles via Convoy'
			'France: A Burgundy Supports A Gascony - Marseilles'
			'France: F Mid-Atlantic Ocean Convoys A Gascony - Marseilles'
			'France: F Western Mediterranean Convoys A Gascony - Marseilles'
			'France: F Gulf of Lyon Convoys A Gascony - Marseilles'
			'Italy: A Marseilles Hold'
		]
		retreats: [
			'Italy: A Marseilles - Gascony', SUCCEEDS
		]

	r '6.H.12. Retreat when dislodged by adjacent convoy while trying to do the same',
		moves: [
			'England: A Liverpool - Edinburgh via Convoy'
			'England: F Irish Sea Convoys A Liverpool - Edinburgh'
			'England: F English Channel Convoys A Liverpool - Edinburgh'
			'England: F North Sea Convoys A Liverpool - Edinburgh'
			'France: F Brest - English Channel'
			'France: F Mid-Atlantic Ocean Supports F Brest - English Channel'
			'Russia: A Edinburgh - Liverpool via Convoy'
			'Russia: F Norwegian Sea Convoys A Edinburgh - Liverpool'
			'Russia: F North Atlantic Ocean Convoys A Edinburgh - Liverpool'
			'Russia: A Clyde Supports A Edinburgh - Liverpool'
		]
		retreats: [
			'England: A Liverpool - Edinburgh', SUCCEEDS
		]

	r '6.H.13. No retreat with convoy in main phase',
		moves: [
			'England: A Picardy Hold'
			'England: F English Channel Convoys A Picardy - London'
			'France: A Paris - Picardy'
			'France: A Brest Supports A Paris - Picardy'
		]
		retreats: [
			'England: A Picardy - London', FAILS
		]

	r '6.H.14. No retreat with support in main phase',
		moves: [
			'England: A Picardy Hold'
			'England: F English Channel Supports A Picardy - Belgium'
			'France: A Paris - Picardy'
			'France: A Brest Supports A Paris - Picardy'
			'France: A Burgundy Hold'
			'Germany: A Munich Supports A Marseilles - Burgundy'
			'Germany: A Marseilles - Burgundy'
		]
		retreats: [
			'England: A Picardy - Belgium', FAILS
			'France: A Burgundy - Belgium', FAILS
		]

	r '6.H.15. No coastal crawl in retreat',
		moves: [
			'England: F Portugal Hold'
			'France: F Spain(sc) - Portugal'
			'France: F Mid-Atlantic Ocean Supports F Spain(sc) - Portugal'
		]
		retreats: [
			'France: F Spain(sc) - Spain(nc)', FAILS
		]

	r '6.H.16. Contested for both coasts',
		moves: [
			'France: F Mid-Atlantic Ocean - Spain(nc)'
			'France: F Gascony - Spain(nc)'
			'France: F Western Mediterranean Hold'
			'Italy: F Tunis Supports F Tyrrhenian Sea - Western Mediterranean'
			'Italy: F Tyrrhenian Sea - Western Mediterranean'
		]
		retreats: [
			'France: F Spain(nc) - Spain(sc)', FAILS
		]

	console.log "Testing builds"
	console.log "--------------\n"

	b '6.I.1. Too many build orders',
		'Germany: Build A Warsaw', SUCCEEDS
		'Germany: Build A Kiel', FAILS
		'Germany: Build A Munich', FAILS

	b '6.I.2. Fleets can not be build in land areas',
		'Russia: Build F Moscow', FAILS

	b '6.I.3. Supply center must be empty for building'
		'Germany: Build A Berlin', FAILS

	b '6.I.4. Both coasts must be empty for building',
		'Russia: Build A St Petersburg(nc)', FAILS

	b '6.I.5. Building in home supply center that is not owned'
		'Germany: Build A Berlin', FAILS

	b '6.I.6. Building in owned supply center that is not a home supply center'
		'Germany: Build A Warsaw', FAILS

	b '6.I.7. Only one build in a home supply center'
		'Russia: Build A Moscow', SUCCEEDS
		'Russia: Build A Moscow', FAILS

# Catch failed promises
process.on 'unhandledRejection', (reason, p) ->
  debug 'Unhandled Rejection at: ', p, 'reason: ', reason

try
	gdata = JSON.parse fs.readFileSync './test_game_data.json'
	gdata.map_data = JSON.parse gdata.map_data
catch e
	console.log 'Failed to read sample game from test_game_data.json'

	debug e
	process.exit 1

datc Board gdata
