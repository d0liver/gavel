{MongoClient} = require 'mongodb'
co            = require 'co'
fs            = require 'fs'

DB_URI                             = "mongodb://localhost:27017/deadpotato"
Engine                             = require '../lib/Engine'
Resolver                           = require '../lib/Resolver'
{UserException, ResolverException} = require '../lib/Exceptions'

# Catch failed promises
process.on 'unhandledRejection', (reason, p) ->
  console.log 'Unhandled Rejection at: ', p, 'reason: ', reason

MongoClient.connect DB_URI, co.wrap (err, db) ->

	try
		gdata = fs.readFileSync './test_game_data.json'
	catch e
		console.log 'Failed to read sample game from test_game_data.json'
		process.exit 1

	gdata.map_data = JSON.parse gdata.map_data

	board = Board gdata

	runTests = ->
		console.log "Running DATC tests....\n"

		test 'Illegal move - move to non-adjacent region',
			'England: F North Sea - Picardy', 'FAILS'

		test 'Illegal move - Army to sea',
			'England: A Liverpool - Irish Sea', 'FAILS'

		test 'Illegal move - Fleet to land',
			'Germany: F Kiel - Munich', 'FAILS'

		test 'Illegal move - Unit to its own region',
			'Germany: F Kiel - Kiel', 'FAILS'

		test 'Illegal move - Unit convoy to its own region',
			'England: F North Sea Convoys A Yorkshire - Yorkshire', 'SUCCEEDS'
			'England: A Yorkshire - Yorkshire', 'FAILS'
			'England: A Liverpool Supports A Yorkshire - Yorkshire', 'SUCCEEDS'
			'Germany: F London - Yorkshire', 'SUCCEEDS'
			'Germany: A Wales Supports F London - Yorkshire', 'SUCCEEDS'

		# NOTE: 6.A.6 doesn't belong here (implementation differences) and
		# should be tested elsewhere (be sure to add orders in such a way that
		# the user is checked for their country first, i.e., no orders will
		# ever exist for the wrong country at this level)

		test 'Illegal move - Only armies can be convoyed', 'FAILS',
			'England: F London - Belgium'
			'England: F North Sea Convoys A London - Belgium'

		test 'Illegal support - An army cannot support itself to hold', 'FAILS',
			'Italy: A Venice - Trieste'
			'Italy: A Tyrolia Supports A Venice - Trieste'
			'Austria: F Trieste Supports F Trieste - Trieste'

	test = (test_name, expected_result, orders...) ->
		console.log "Test: #{test_name}"
		succeeds = true
		expected_result = expected_result is 'SUCCEEDS'

		for i in [0...orders.length] by 2
			[order, expected_result] = orders[i..i+1]
			console.log "Adding order: ", parseOrder(order)
			console.log "Expected result is: ", expected_result
			engine.addOrder(parseOrder(order))

		results = engine.resolve()
		console.log "RESULT: ", results
		engine.clearOrders()

		for result,i in results
			expected_result = orders[i+1] is 'SUCCEEDS'
			if expected_result isnt result.succeeds
				console.log "FAILURE: #{test_name}\n"
				break

		console.log "SUCCESS: #{test_name}\n"

	runTests()
