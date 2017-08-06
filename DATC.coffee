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

	t 'Convoy swap - If in a swap one of the unit bounces, then the swap fails',
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

	t '6.D.11. Test case, no self dislodgment of returning unit',
		'Germany: A Berlin - Prussia', 'FAILS'
		'Germany: F Kiel - Berlin', 'FAILS'
		'Germany: A Munich Supports F Kiel - Berlin', 'SUCCEEDS'
		'Russia: A Warsaw - Prussia', 'FAILS'

	t '6.D.12. Test case, support a foreign unit to dislodge own unit prohibited',
		'Austria: F Trieste Hold', 'SUCCEEDS'
		'Austria: A Vienna Supports A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Venice - Trieste', 'FAILS'

	t '
		6.D.13. Test case, supporting a foreign unit to dislodge returning own
		unit prohibited.
	',
		'Austria: F Trieste - Adriatic Sea', 'FAILS'
		'Austria: A Vienna Supports A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Venice - Trieste', 'FAILS'
		'Italy: F Apulia - Adriatic Sea', 'FAILS'

	t '
		6.D.14. Test case, supporting a foreign unit is not enough to prevent
		dislodgement
	',
		'Austria: F Trieste Hold', 'FAILS'
		'Austria: A Vienna Supports A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Venice - Trieste', 'SUCCEEDS'
		'Italy: A Tyrolia Supports A Venice - Trieste', 'SUCCEEDS'
		'Italy: F Adriatic Sea Supports A Venice - Trieste', 'SUCCEEDS'

	t 'Illegal Support Cut - A unit cannot cut support into its own region',
		'Russia: F Constantinople Supports F Black Sea - Ankara', 'SUCCEEDS'
		'Russia: F Black Sea - Ankara', 'SUCCEEDS'
		'Turkey: F Ankara - Constantinople', 'FAILS'

	# 6.D.16

test = (board, test_name, args...) ->
	console.log "Test: #{test_name}"

	orders = (parseOrder arg for arg in args by 2)
	resolver = Resolver board, orders, true

	for order, i in orders
		# Expected results are given after each order in the args.
		expect = args[2*i+1]
		result = resolver.resolve order

		if result isnt expect
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
