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
		'Italy: A Apulia - Venice', 'FAILS'

	t 'Regular bounce - Two armies bouncing with each other',
		'Austria: A Vienna - Tyrolia', 'FAILS'
		'Italy: A Venice - Tyrolia', 'FAILS'

	t 'Regular bounce - Three armies bouncing with each other',
		'Austria: A Vienna - Tyrolia', 'FAILS'
		'Germany: A Munich - Tyrolia', 'FAILS'
		'Italy: A Venice - Tyrolia', 'FAILS'

	t 'Coastal issues - Coast not specified',
		'France: F Portugal - Spain', 'ILLEGAL'

	t 'Coastal issues - illegal coast',
		'France: F Gascony - Spain(sc)', 'FAILS'

	t 'Coastal issues - fleet support to non adjacent coast',
		'France: F Gascony - Spain(nc)', 'SUCCEEDS'
		# 'France: F Marseilles Supports F Gascony - Spain(nc)', 'SUCCEEDS'
		# 'Italy: F Western Mediterranean - Spain(sc)', 'FAILS'

test = (board, test_name, args...) ->
	console.log "Test: #{test_name}"

	orders = (parseOrder arg for arg in args by 2)
	resolver = Resolver board, orders, true

	for order, i in orders
		# Expected results are given after each order in the args.
		expect = args[2*i+1]

		result = resolver.resolve order
		debug 'Evaluated order: ', args[2*i]
		# debug 'Parsed order: ', order
		debug "Expect: #{expect}, Actual: #{result}"

		if result isnt expect
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
