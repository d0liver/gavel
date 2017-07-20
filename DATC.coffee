# Node
fs = require 'fs'

# Local
Resolver                           = require './Resolver'
{UserException, ResolverException} = require './Exceptions'
debug                              = require './debug'
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

	# test 'Illegal move - Fleet to land',
	# 	'Germany: F Kiel - Munich', 'FAILS'

	# test 'Illegal move - Unit to its own region',
	# 	'Germany: F Kiel - Kiel', 'FAILS'

	# test 'Illegal move - Unit convoy to its own region',
	# 	'England: F North Sea Convoys A Yorkshire - Yorkshire', 'SUCCEEDS'
	# 	'England: A Yorkshire - Yorkshire', 'FAILS'
	# 	'England: A Liverpool Supports A Yorkshire - Yorkshire', 'SUCCEEDS'
	# 	'Germany: F London - Yorkshire', 'SUCCEEDS'
	# 	'Germany: A Wales Supports F London - Yorkshire', 'SUCCEEDS'

	# NOTE: 6.A.6 doesn't belong here (implementation differences) and
	# should be tested elsewhere (be sure to add orders in such a way that
	# the user is checked for their country first, i.e., no orders will
	# ever exist for the wrong country at this level)

	# test 'Illegal move - Only armies can be convoyed', 'FAILS',
	# 	'England: F London - Belgium'
	# 	'England: F North Sea Convoys A London - Belgium'

	# test 'Illegal support - An army cannot support itself to hold', 'FAILS',
	# 	'Italy: A Venice - Trieste'
	# 	'Italy: A Tyrolia Supports A Venice - Trieste'
	# 	'Austria: F Trieste Supports F Trieste - Trieste'

test = (board, test_name, args...) ->
	console.log "Test: #{test_name}"

	orders = (parseOrder arg for arg in args by 2)
	resolver = Resolver board, orders

	for order, i in orders
		# Expected results are given after each order in the args.
		expect = args[2*i+1]

		debug "Expected result is: ", expect
		debug "Result was: ", resolver.resolve(order)
		if resolver.resolve(order) isnt expect
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
