# Node
fs = require 'fs'

# Local
Resolver                           = require './Resolver'
{UserException, ResolverException} = require './Exceptions'
debug                              = require('./debug') 'DATC'
Board                              = require './Board'
parseOrder                         = require './parseOrder'

DB_URI = "mongodb://localhost:27017/deadpotato"

datc = (board) ->
	t = test.bind null, board
	console.log "Running DATC tests....\n"

	# Fails but not 'ILLEGAL' because we don't explicitly check for a convoy path
	# before the order is resolved.
	t 'Illegal move - move to non-adjacent region',
		'Austria: F Budapest - Moscow', 'FAILS'

	t 'Illegal move - Army to sea',
		'England: A Liverpool - Irish Sea', 'FAILS'

	t 'Illegal move - Fleet to land',
		'Germany: F Kiel - Munich', 'FAILS'

	t 'Illegal move - Unit to its own region',
		'Germany: F Kiel - Kiel', 'ILLEGAL'

	t 'Illegal move - Unit convoy to its own region',
		'England: F North Sea Convoys A Yorkshire - Yorkshire', 'ILLEGAL'
		'England: A Yorkshire - Yorkshire', 'ILLEGAL'
		'England: A Liverpool Supports A Yorkshire - Yorkshire', 'ILLEGAL'
		'Germany: F London - Yorkshire', 'SUCCEEDS'
		'Germany: A Wales Supports F London - Yorkshire', 'SUCCEEDS'

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
		'England: F London - Belgium', 'FAILS'
		'England: F North Sea Convoys A London - Belgium', 'SUCCEEDS'

	t 'Illegal support - An army cannot support itself to hold',
		'Italy: A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Tyrolia Supports A Venice - Trieste', 'SUCCEEDS'
		'Austria: F Trieste Supports F Trieste - Trieste', 'ILLEGAL'

	t 'Illegal move - Fleets must follow coast if not on sea',
		'Italy: F Rome - Venice', 'FAILS'

	t 'Illegal support - Support on unreachable destination not possible',
		'Austria: A Venice Hold', 'SUCCEEDS'
		'Italy: F Rome Supports A Apulia - Venice', 'ILLEGAL'
		# 'Italy: A Apulia - Venice', 'FAILS'

	t 'Regular bounce - Two armies bouncing with each other',
		'Austria: A Vienna - Tyrolia', 'FAILS'
		'Italy: A Venice - Tyrolia', 'FAILS'

	t 'Regular bounce - Three armies bouncing with each other',
		'Austria: A Vienna - Tyrolia', 'FAILS'
		'Germany: A Munich - Tyrolia', 'FAILS'
		'Italy: A Venice - Tyrolia', 'FAILS'

	t 'Coastal issues - Coast not specified',
		'France: F Portugal - Spain', 'FAILS'

	t 'Coastal issues - illegal coast',
		'France: F Gascony - Spain(sc)', 'FAILS'

	t 'Coastal issues - fleet support to non adjacent coast',
		'France: F Gascony - Spain(nc)', 'SUCCEEDS'
		# 'France: F Marseilles Supports F Gascony - Spain(nc)', 'SUCCEEDS'
		# 'Italy: F Western Mediterranean - Spain(sc)', 'FAILS'

	t 'Coastal issues - A fleet cannot support into an area that is unreachable from its coast',
		'France: F Spain(nc) Supports F Marseilles - Gulf of Lyon', 'ILLEGAL'
		'Italy: F Gulf of Lyon Hold', 'SUCCEEDS'
		'France: F Marseilles - Gulf of Lyon', 'FAILS'

	t 'Coastal issues - Support can be cut from the other coast',
		'England: F Irish Sea Supports F North Atlantic Ocean - Mid-Atlantic Ocean', 'SUCCEEDS'
		'England: F North Atlantic Ocean - Mid-Atlantic Ocean', 'SUCCEEDS'
		'France: F Spain(nc) Supports F Mid-Atlantic Ocean Hold', 'FAILS'
		'France: F Mid-Atlantic Ocean Hold', 'FAILS'
		'Italy: F Gulf of Lyon - Spain(sc)', 'FAILS'

	t 'Coastal issues - Most house rules accept support orders without coast specification',
		'France: F Portugal Supports F Mid-Atlantic Ocean - Spain', 'SUCCEEDS'
		'France: F Mid-Atlantic Ocean - Spain(nc)', 'FAILS'
		'Italy: F Gulf of Lyon Supports F Western Mediterranean - Spain(sc)', 'SUCCEEDS'
		'Italy: F Western Mediterranean - Spain(sc)', 'FAILS'

	# TODO: Double check that 6.B.8 through 6.B.12 are unnecessary

	t 'Coastal issues - Coastal crawl forbidden',
		'Turkey: F Bulgaria(sc) - Constantinople', 'FAILS'
		'Turkey: F Constantinople - Bulgaria(ec)', 'FAILS'

	# TODO: 6.B.14 build order issues

	t 'Circular movement - basic',
		'Turkey: F Ankara - Constantinople', 'SUCCEEDS'
		'Turkey: A Constantinople - Smyrna', 'SUCCEEDS'
		'Turkey: A Smyrna - Ankara', 'SUCCEEDS'

	t 'Circular movement - Three units can change place, even when one gets support',
		'Turkey: F Ankara - Constantinople', 'SUCCEEDS'
		'Turkey: A Constantinople - Smyrna', 'SUCCEEDS'
		'Turkey: A Smyrna - Ankara', 'SUCCEEDS'
		'Turkey: A Bulgaria Supports F Ankara - Constantinople', 'SUCCEEDS'

	t 'Circular movement - One unit bounces, the whole circular movement is blocked',
		'Turkey: F Ankara - Constantinople', 'FAILS'
		'Turkey: A Constantinople - Smyrna', 'FAILS'
		'Turkey: A Smyrna - Ankara', 'FAILS'
		'Turkey: A Bulgaria - Constantinople', 'FAILS'

	t 'Circular movement - Movement contains an attacked convoy, still succeeds',
		'Austria: A Trieste - Serbia', 'SUCCEEDS'
		'Austria: A Serbia - Bulgaria', 'SUCCEEDS'
		'Turkey: A Bulgaria - Trieste', 'SUCCEEDS'
		'Turkey: F Aegean Sea Convoys A Bulgaria - Trieste', 'SUCCEEDS'
		'Turkey: F Ionian Sea Convoys A Bulgaria - Trieste', 'SUCCEEDS'
		'Turkey: F Adriatic Sea Convoys A Bulgaria - Trieste', 'SUCCEEDS'

	t 'Circular movement - Disrupted circular movement due to dislodged convoy',
		'Austria: A Trieste - Serbia', 'FAILS'
		'Austria: A Serbia - Bulgaria', 'FAILS'
		'Turkey: A Bulgaria - Trieste', 'FAILS'
		'Turkey: F Aegean Sea Convoys A Bulgaria - Trieste', 'SUCCEEDS'
		'Turkey: F Ionian Sea Convoys A Bulgaria - Trieste', 'FAILS'
		'Turkey: F Adriatic Sea Convoys A Bulgaria - Trieste', 'SUCCEEDS'
		'Italy: F Naples - Ionian Sea', 'SUCCEEDS'
		'Italy: F Tunis Supports F Naples - Ionian Sea', 'SUCCEEDS'

	t 'Convoy swap - Two armies can swap places even when they are not adjacent.',
		'England: F North Sea Convoys A London - Belgium', 'SUCCEEDS'
		'England: A London - Belgium', 'SUCCEEDS'
		'France: F English Channel Convoys A Belgium - London', 'SUCCEEDS'
		'France: A Belgium - London', 'SUCCEEDS'

	t 'Convoy swap - If in a swap one of the units bounces, then the swap fails',
		'England: F North Sea Convoys A London - Belgium', 'SUCCEEDS'
		'England: A London - Belgium', 'FAILS'
		'France: F English Channel Convoys A Belgium - London', 'SUCCEEDS'
		'France: A Belgium - London', 'FAILS'
		'France: A Burgundy - Belgium', 'FAILS'

	t 'Support to hold - The simplest support to hold order',
		'Austria: F Adriatic Sea Supports A Trieste - Venice', 'SUCCEEDS'
		'Austria: A Trieste - Venice', 'FAILS'
		'Italy: A Venice Hold', 'SUCCEEDS'
		'Italy: A Tyrolia Supports A Venice Hold', 'SUCCEEDS'

	t 'Support to hold - The most simple support on hold cut',
		'Austria: F Adriatic Sea Supports A Trieste - Venice', 'SUCCEEDS'
		'Austria: A Trieste - Venice', 'SUCCEEDS'
		'Austria: A Vienna - Tyrolia', 'FAILS'
		'Italy: A Venice Hold', 'FAILS'
		'Italy: A Tyrolia Supports A Venice Hold', 'FAILS'

	t 'Support on move - The most simple support on move cut',
		'Austria: F Adriatic Sea Supports A Trieste - Venice', 'FAILS'
		'Austria: A Trieste - Venice', 'FAILS'
		'Italy: A Venice Hold', 'SUCCEEDS'
		'Italy: F Ionian Sea - Adriatic Sea', 'FAILS'

	t 'Support hold - A unit that is supporting a hold, can receive a hold support',
		'Germany: A Berlin Supports F Kiel Hold', 'FAILS'
		'Germany: F Kiel Supports A Berlin Hold', 'SUCCEEDS'
		'Russia: A Prussia - Berlin', 'FAILS'
		'Russia: F Baltic Sea Supports A Prussia - Berlin', 'SUCCEEDS'

	t 'Support hold - A unit that is supporting a move, can receive a hold support',
		'Germany: A Berlin Supports A Munich - Silesia', 'FAILS'
		'Germany: F Kiel Supports A Berlin Hold', 'SUCCEEDS'
		'Germany: A Munich - Silesia', 'SUCCEEDS'
		'Russia: F Baltic Sea Supports A Prussia - Berlin', 'SUCCEEDS'
		'Russia: A Prussia - Berlin', 'FAILS'

	t 'Support hold - A unit that is convoying, can receive a hold support',
		'Germany: A Berlin - Sweden', 'SUCCEEDS'
		'Germany: F Baltic Sea Convoys A Berlin - Sweden', 'SUCCEEDS'
		'Germany: F Prussia Supports F Baltic Sea Hold', 'SUCCEEDS'
		'Russia: F Livonia - Baltic Sea', 'FAILS'
		'Russia: F Gulf of Bothnia Supports F Livonia - Baltic Sea', 'SUCCEEDS'

	t 'Support hold - A unit that is moving cannot receive a hold support if the move fails',
		'Germany: F Baltic Sea - Sweden', 'FAILS'
		'Germany: F Prussia Supports F Baltic Sea Hold', 'ILLEGAL'
		'Russia: F Livonia - Baltic Sea', 'SUCCEEDS'
		'Russia: F Gulf of Bothnia Supports F Livonia - Baltic Sea', 'SUCCEEDS'
		'Russia: A Finland - Sweden', 'FAILS'

	t 'Support hold - Failed convoy can not receive hold support',
		'Austria: F Ionian Sea Hold', 'SUCCEEDS'
		'Austria: A Serbia Supports A Albania - Greece', 'SUCCEEDS'
		'Austria: A Albania - Greece', 'SUCCEEDS'
		'Turkey: A Greece - Naples', 'FAILS'
		'Turkey: A Bulgaria Supports A Greece Hold', 'ILLEGAL'

	t 'Hold - A unit that is holding can not receive a support in moving',
		'Italy: A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Tyrolia Supports A Venice - Trieste', 'SUCCEEDS'
		'Austria: A Albania Supports A Trieste - Serbia', 'SUCCEEDS'
		'Austria: A Trieste Hold', 'FAILS'

	# TODO: This may be a bit tricky. - through 6.D.15
	t 'Illegal dislodge - A unit may not dislodge a unit of the same great power',
		'Germany: A Berlin Hold', 'SUCCEEDS'
		'Germany: F Kiel - Berlin', 'FAILS'
		'Germany: A Munich Supports F Kiel - Berlin', 'SUCCEEDS'

	t '6.D.11. No self dislodgment of returning unit',
		'Germany: A Berlin - Prussia', 'FAILS'
		'Germany: F Kiel - Berlin', 'FAILS'
		'Germany: A Munich Supports F Kiel - Berlin', 'SUCCEEDS'
		'Russia: A Warsaw - Prussia', 'FAILS'

	t '6.D.12. Support a foreign unit to dislodge own unit prohibited',
		'Austria: F Trieste Hold', 'SUCCEEDS'
		'Austria: A Vienna Supports A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Venice - Trieste', 'FAILS'

	t '
		6.D.13. Supporting a foreign unit to dislodge returning own
		unit prohibited.
	',
		'Austria: F Trieste - Adriatic Sea', 'FAILS'
		'Austria: A Vienna Supports A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Venice - Trieste', 'FAILS'
		'Italy: F Apulia - Adriatic Sea', 'FAILS'

	t '
		6.D.14. Supporting a foreign unit is not enough to prevent
		dislodgement
	',
		'Austria: F Trieste Hold', 'FAILS'
		'Austria: A Vienna Supports A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Tyrolia Supports A Venice - Trieste', 'SUCCEEDS'
		'Italy: F Adriatic Sea Supports A Venice - Trieste', 'SUCCEEDS'

	t '6.D.15 Illegal Support Cut - A unit cannot cut support into its own region',
		'Russia: F Constantinople Supports F Black Sea - Ankara', 'SUCCEEDS'
		'Russia: F Black Sea - Ankara', 'SUCCEEDS'
		'Turkey: F Ankara - Constantinople', 'FAILS'

	t 'Convoying a unit dislodging a unit of same power is allowed',
		'England: A London Hold', 'FAILS'
		'England: F North Sea Convoys A Belgium - London', 'SUCCEEDS'
		'France: F English Channel Supports A Belgium - London', 'SUCCEEDS'
		'France: A Belgium - London', 'SUCCEEDS'

	t '6.D.17. Dislodgement cuts supports',
		'Russia: F Constantinople Supports F Black Sea - Ankara', 'FAILS'
		'Russia: F Black Sea - Ankara', 'FAILS'
		'Turkey: F Ankara - Constantinople', 'SUCCEEDS'
		'Turkey: A Smyrna Supports F Ankara - Constantinople', 'SUCCEEDS'
		'Turkey: A Armenia - Ankara', 'FAILS'

	t '6.D.18. A surviving unit will sustain support',
		'Russia: F Constantinople Supports F Black Sea - Ankara', 'SUCCEEDS'
		'Russia: F Black Sea - Ankara', 'SUCCEEDS'
		'Russia: A Bulgaria Supports F Constantinople Hold', 'SUCCEEDS'
		'Turkey: F Ankara - Constantinople', 'FAILS'
		'Turkey: A Smyrna Supports F Ankara - Constantinople', 'SUCCEEDS'
		'Turkey: A Armenia - Ankara', 'FAILS'

	t '6.D.19. Even when surviving is in alternative way',
		'Russia: F Constantinople Supports F Black Sea - Ankara', 'SUCCEEDS'
		'Russia: F Black Sea - Ankara', 'SUCCEEDS'
		'Russia: A Smyrna Supports F Ankara - Constantinople', 'SUCCEEDS'
		'Turkey: F Ankara - Constantinople', 'FAILS'

	t '6.D.20. Unit can not cut support of its own country',
		'England: F London Supports F North Sea - English Channel', 'SUCCEEDS'
		'England: F North Sea - English Channel', 'SUCCEEDS'
		'England: A Yorkshire - London', 'FAILS'
		'France: F English Channel Hold', 'FAILS'

	t '6.D.21. Dislodging does not cancel a support cut',
		'Austria: F Trieste Hold', 'SUCCEEDS'
		'Italy: A Venice - Trieste', 'FAILS'
		'Italy: A Tyrolia Supports A Venice - Trieste', 'FAILS'
		'Germany: A Munich - Tyrolia', 'FAILS'
		'Russia: A Silesia - Munich', 'SUCCEEDS'
		'Russia: A Berlin Supports A Silesia - Munich', 'SUCCEEDS'

	t '6.D.22. Impossible fleet move can not be supported',
		'Germany: F Kiel - Munich', 'FAILS'
		'Germany: A Burgundy Supports F Kiel - Munich', 'SUCCEEDS'
		'Russia: A Munich - Kiel', 'SUCCEEDS'
		'Russia: A Berlin Supports A Munich - Kiel', 'SUCCEEDS'

	t '6.D.23. Impossible coast move can not be supported',
		'Italy: F Gulf of Lyon - Spain(sc)', 'SUCCEEDS'
		'Italy: F Western Mediterranean Supports F Gulf of Lyon - Spain(sc)', 'SUCCEEDS'
		'France: F Spain(nc) - Gulf of Lyon', 'FAILS'
		'France: F Marseilles Supports F Spain(nc) - Gulf of Lyon', 'SUCCEEDS'

	t '6.D.24. Impossible army move can not be supported',
		'France: A Marseilles - Gulf of Lyon', 'FAILS'
		'France: F Spain(sc) Supports A Marseilles - Gulf of Lyon', 'ILLEGAL'
		'Italy: F Gulf of Lyon Hold', 'FAILS'
		'Turkey: F Western Mediterranean - Gulf of Lyon', 'SUCCEEDS'
		'Turkey: F Tyrrhenian Sea Supports F Western Mediterranean - Gulf of Lyon', 'SUCCEEDS'

	t '6.D.25. Failing hold support can be supported',
		'Germany: A Berlin Supports A Prussia Hold', 'ILLEGAL'
		'Germany: F Kiel Supports A Berlin Hold', 'SUCCEEDS'
		'Russia: F Baltic Sea Supports A Prussia - Berlin', 'SUCCEEDS'
		'Russia: A Prussia - Berlin', 'FAILS'

	t '6.D.26. Failing move support can be supported',
		'Germany: A Berlin Supports A Prussia - Silesia', 'FAILS'
		'Germany: F Kiel Supports A Berlin Hold', 'SUCCEEDS'
		'Russia: F Baltic Sea Supports A Prussia - Berlin', 'SUCCEEDS'
		'Russia: A Prussia - Berlin', 'FAILS'

	t '6.D.27. Failing convoy can be supported',
		'England: F Sweden - Baltic Sea', 'FAILS'
		'England: F Denmark Supports F Sweden - Baltic Sea', 'SUCCEEDS'
		'Germany: A Berlin Hold', 'SUCCEEDS'
		'Russia: F Baltic Sea Convoys A Berlin - Livonia', 'SUCCEEDS'
		'Russia: F Prussia Supports F Baltic Sea Hold', 'SUCCEEDS'

	# TODO: This test case is failing according to preferences but technically
	# still correct and consistent. Special handling could make it a little
	# more user friendly as suggested in the DATC cases. 6.D.29 and 30 are
	# similar kinds of things.
	t '6.D.28. Impossible move and support',
		'Austria: A Budapest Supports F Rumania Hold', 'ILLEGAL'
		'Russia: F Rumania - Holland', 'FAILS'
		'Turkey: F Black Sea - Rumania', 'SUCCEEDS'
		'Turkey: A Bulgaria Supports F Black Sea - Rumania', 'SUCCEEDS'

	# TODO: This may deserve more attention but it's another one of those
	# things where it has to do with determining which orders should be
	# considred illegal and thrown out rather than the correctness of the
	# adjudicator itself.
	t '6.D.31. A tricky impossible support',
		'Austria: A Rumania - Armenia', 'FAILS'
		'Turkey: F Black Sea Supports A Rumania - Armenia', 'SUCCEEDS'

	t '6.D.33. Unwanted support allowed',
		'Austria: A Serbia - Budapest', 'SUCCEEDS'
		'Austria: A Vienna - Budapest', 'FAILS'
		'Russia: A Galicia Supports A Serbia - Budapest', 'SUCCEEDS'
		'Turkey: A Bulgaria - Serbia', 'SUCCEEDS'

	t '6.D.34. Support targeting own area not allowed',
		'Germany: A Berlin - Prussia', 'SUCCEEDS'
		'Germany: A Silesia Supports A Berlin - Prussia', 'SUCCEEDS'
		'Germany: F Baltic Sea Supports A Berlin - Prussia', 'SUCCEEDS'
		'Italy: A Prussia Supports A Livonia - Prussia', 'ILLEGAL'
		'Russia: A Warsaw Supports A Livonia - Prussia', 'SUCCEEDS'
		'Russia: A Livonia - Prussia', 'FAILS'

	t '6.E.1. Dislodged unit has no effect on attackers area',
		'Germany: A Berlin - Prussia', 'SUCCEEDS'
		'Germany: F Kiel - Berlin', 'SUCCEEDS'
		'Germany: A Silesia Supports A Berlin - Prussia', 'SUCCEEDS'
		'Russia: A Prussia - Berlin', 'FAILS'

	t '6.E.2. No self dislodgement in head to head battle',
		'Germany: A Berlin - Kiel', 'FAILS'
		'Germany: F Kiel - Berlin', 'FAILS'
		'Germany: A Munich Supports A Berlin - Kiel', 'SUCCEEDS'

	t '6.E.3. No help in dislodging own unit',
		'Germany: A Berlin - Kiel', 'FAILS'
		'Germany: A Munich Supports F Kiel - Berlin', 'SUCCEEDS'
		'England: F Kiel - Berlin', 'FAILS'

	t '6.E.4. Non-dislodged loser has still effect',
		'Germany: F Holland - North Sea', 'FAILS'
		'Germany: F Helgoland Bight Supports F Holland - North Sea', 'SUCCEEDS'
		'Germany: F Skagerrak Supports F Holland - North Sea', 'SUCCEEDS'
		'France: F North Sea - Holland', 'FAILS'
		'France: F Belgium Supports F North Sea - Holland', 'SUCCEEDS'
		'England: F Edinburgh Supports F Norwegian Sea - North Sea', 'SUCCEEDS'
		'England: F Yorkshire Supports F Norwegian Sea - North Sea', 'SUCCEEDS'
		'England: F Norwegian Sea - North Sea', 'FAILS'
		'Austria: A Kiel Supports A Ruhr - Holland', 'SUCCEEDS'
		'Austria: A Ruhr - Holland', 'FAILS'

	t '6.E.5. Loser dislodged by another army has still effect',
		'Germany: F Holland - North Sea', 'FAILS'
		'Germany: F Helgoland Bight Supports F Holland - North Sea', 'SUCCEEDS'
		'Germany: F Skagerrak Supports F Holland - North Sea', 'SUCCEEDS'
		'France: F North Sea - Holland', 'FAILS'
		'France: F Belgium Supports F North Sea - Holland', 'SUCCEEDS'
		'England: F Edinburgh Supports F Norwegian Sea - North Sea', 'SUCCEEDS'
		'England: F Yorkshire Supports F Norwegian Sea - North Sea', 'SUCCEEDS'
		'England: F Norwegian Sea - North Sea', 'SUCCEEDS'
		'England: F London Supports F Norwegian Sea - North Sea', 'SUCCEEDS'
		'Austria: A Kiel Supports A Ruhr - Holland', 'SUCCEEDS'
		'Austria: A Ruhr - Holland', 'FAILS'

	t '6.E.6. Not dislodge because of own support has still effect',
		'Germany: F Holland - North Sea', 'FAILS'
		'Germany: F Helgoland Bight Supports F Holland - North Sea', 'SUCCEEDS'
		'France: F North Sea - Holland', 'FAILS'
		'France: F Belgium Supports F North Sea - Holland', 'SUCCEEDS'
		'France: F English Channel Supports F Holland - North Sea', 'SUCCEEDS'
		'Austria: A Kiel Supports A Ruhr - Holland', 'SUCCEEDS'
		'Austria: A Ruhr - Holland', 'FAILS'

	t '6.E.7. No self dislodgement with beleaguered garrison',
		'England: F North Sea Hold', 'SUCCEEDS'
		'England: F Yorkshire Supports F Norway - North Sea', 'SUCCEEDS'
		'Germany: F Holland Supports F Helgoland Bight - North Sea', 'SUCCEEDS'
		'Germany: F Helgoland Bight - North Sea', 'FAILS'
		'Russia: F Skagerrak Supports F Norway - North Sea', 'SUCCEEDS'
		'Russia: F Norway - North Sea', 'FAILS'

	t '6.E.8. Test case, no self dislodgement with beleaguered garrison and head to head battle',
		'England: F North Sea - Norway', 'FAILS'
		'England: F Yorkshire Supports F Norway - North Sea', 'SUCCEEDS'
		'Germany: F Holland Supports F Helgoland Bight - North Sea', 'SUCCEEDS'
		'Germany: F Helgoland Bight - North Sea', 'FAILS'
		'Russia: F Skagerrak Supports F Norway - North Sea', 'SUCCEEDS'
		'Russia: F Norway - North Sea', 'FAILS'

	t '6.E.9. Almost self dislodgement with beleaguered garrison',
		'England: F North Sea - Norwegian Sea', 'SUCCEEDS'
		'England: F Yorkshire Supports F Norway - North Sea', 'SUCCEEDS'
		'Germany: F Helgoland Bight - North Sea', 'FAILS'
		'Germany: F Holland Supports F Helgoland Bight - North Sea', 'SUCCEEDS'
		'Russia: F Norway - North Sea', 'SUCCEEDS'
		'Russia: F Skagerrak Supports F Norway - North Sea', 'SUCCEEDS'

	t '6.E.10. Almost circular movement with no self dislodgement with beleaguered garrison',
		'England: F North Sea - Denmark', 'FAILS'
		'England: F Yorkshire Supports F Norway - North Sea', 'SUCCEEDS'
		'Germany: F Holland Supports F Helgoland Bight - North Sea', 'SUCCEEDS'
		'Germany: F Helgoland Bight - North Sea', 'FAILS'
		'Germany: F Denmark - Helgoland Bight', 'FAILS'
		'Russia: F Skagerrak Supports F Norway - North Sea', 'SUCCEEDS'
		'Russia: F Norway - North Sea', 'FAILS'

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
		'Austria: A Budapest - Rumania', 'FAILS'
		'Austria: A Serbia Supports A Vienna - Budapest', 'SUCCEEDS'
		'Italy: A Vienna - Budapest', 'FAILS'
		'Russia: A Galicia - Budapest', 'FAILS'
		'Russia: A Rumania Supports A Galicia - Budapest', 'SUCCEEDS'

	t '6.E.13. Three way beleaguered garrison',
		'England: F Edinburgh Supports F Yorkshire - North Sea', 'SUCCEEDS'
		'England: F Yorkshire - North Sea', 'FAILS'
		'France: F Belgium - North Sea', 'FAILS'
		'France: F English Channel Supports F Belgium - North Sea', 'SUCCEEDS'
		'Germany: F North Sea Hold', 'SUCCEEDS'
		'Russia: F Norwegian Sea - North Sea', 'FAILS'
		'Russia: F Norway Supports F Norwegian Sea - North Sea', 'SUCCEEDS'

	t '6.E.14. Illegal head to head battle can still defend',
		'England: A Liverpool - Edinburgh', 'FAILS'
		'Russia: F Edinburgh - Liverpool', 'FAILS'

	t '6.E.15. The friendly head to head battle',
		'England: F Holland Supports A Ruhr - Kiel', 'SUCCEEDS'
		'England: A Ruhr - Kiel', 'FAILS'
		'France: A Kiel - Berlin', 'FAILS'
		'France: A Munich Supports A Kiel - Berlin', 'SUCCEEDS'
		'France: A Silesia Supports A Kiel - Berlin', 'SUCCEEDS'
		'Germany: A Berlin - Kiel', 'FAILS'
		'Germany: F Denmark Supports A Berlin - Kiel', 'SUCCEEDS'
		'Germany: F Helgoland Bight Supports A Berlin - Kiel', 'SUCCEEDS'
		'Russia: F Baltic Sea Supports A Prussia - Berlin', 'SUCCEEDS'
		'Russia: A Prussia - Berlin', 'FAILS'

	t '6.F.1. No convoy in coastal areas',
		'Turkey: A Greece - Sevastopol', 'FAILS'
		'Turkey: F Aegean Sea Convoys A Greece - Sevastopol', 'SUCCEEDS'
		# TODO: This should probably come back as 'ILLEGAL' although it's
		# handled correctly by hasPath so there's no tangible impact
		'Turkey: F Constantinople Convoys A Greece - Sevastopol', 'SUCCEEDS'
		'Turkey: F Black Sea Convoys A Greece - Sevastopol', 'SUCCEEDS'

	t '6.F.2. An army being convoyed can bounce as normal',
		'England: F English Channel Convoys A London - Brest', 'SUCCEEDS'
		'England: A London - Brest', 'FAILS'
		'France: A Paris - Brest', 'FAILS'

	t '6.F.3. An army being convoyed can receive support',
		'England: F English Channel Convoys A London - Brest', 'SUCCEEDS'
		'England: A London - Brest', 'SUCCEEDS'
		'England: F Mid-Atlantic Ocean Supports A London - Brest', 'SUCCEEDS'
		'France: A Paris - Brest', 'FAILS'

	t '6.F.4. An attacked convoy is not disrupted',
		'England: F North Sea Convoys A London - Holland', 'SUCCEEDS'
		'England: A London - Holland', 'SUCCEEDS'
		'Germany: F Skagerrak - North Sea', 'FAILS'

	t '6.F.5. A beleaguered convoy is not disrupted',
		'England: F North Sea Convoys A London - Holland', 'SUCCEEDS'
		'England: A London - Holland', 'SUCCEEDS'
		'France: F English Channel - North Sea', 'FAILS'
		'France: F Belgium Supports F English Channel - North Sea', 'SUCCEEDS'
		'Germany: F Skagerrak - North Sea', 'FAILS'
		'Germany: F Denmark Supports F Skagerrak - North Sea', 'SUCCEEDS'

	t '6.F.6. Dislodged convoy does not cut support',
		'England: F North Sea Convoys A London - Holland', 'FAILS'
		'England: A London - Holland', 'FAILS'
		'Germany: A Holland Supports A Belgium Hold', 'SUCCEEDS'
		'Germany: A Belgium Supports A Holland Hold', 'FAILS'
		'Germany: F Helgoland Bight Supports F Skagerrak - North Sea', 'SUCCEEDS'
		'Germany: F Skagerrak - North Sea', 'SUCCEEDS'
		'France: A Picardy - Belgium', 'FAILS'
		'France: A Burgundy Supports A Picardy - Belgium', 'SUCCEEDS'

	# TODO: Retreats - Dislodged English fleet can retreat to Holland
	# t '6.F.7. Dislodged convoy does not cause contested area',
	# 	'England: F North Sea Convoys A London - Holland'
	# 	'England: A London - Holland'
	# 	'Germany: F Helgoland Bight Supports F Skagerrak - North Sea'
	# 	'Germany: F Skagerrak - North Sea'

	t '6.F.8. Dislodged convoy does not cause a bounce',
		'England: F North Sea Convoys A London - Holland', 'FAILS'
		'England: A London - Holland', 'FAILS'
		'Germany: F Helgoland Bight Supports F Skagerrak - North Sea', 'SUCCEEDS'
		'Germany: F Skagerrak - North Sea', 'SUCCEEDS'
		'Germany: A Belgium - Holland', 'SUCCEEDS'

	t '6.F.9. Dislodge of multi-route convoy',
		'England: F English Channel Convoys A London - Belgium', 'FAILS'
		'England: F North Sea Convoys A London - Belgium', 'SUCCEEDS'
		'England: A London - Belgium', 'SUCCEEDS'
		'France: F Brest Supports F Mid-Atlantic Ocean - English Channel', 'SUCCEEDS'
		'France: F Mid-Atlantic Ocean - English Channel', 'SUCCEEDS'

test = (board, test_name, args...) ->
	console.log "Test: #{test_name}"

	orders = (parseOrder arg for arg in args by 2)
	resolver = Resolver board, orders, TEST: true
	dbg_resolver = Resolver board, orders, {TEST: true, DEBUG: true}

	for order, i in orders
		# Expected results are given after each order in the args.
		expect = args[2*i+1]
		result = resolver.resolve order

		if result isnt expect
			debug 'Test failed, rerunning in debug mode'
			delete order.succeeds
			dbg_resolver.resolve order
			debug 'Evaluated order: ', args[2*i]
			debug "Expect: #{expect}, Actual: #{result}"
			console.log "Test failed\n"
			return false

	console.log "Test succeeded\n"
	return true

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
