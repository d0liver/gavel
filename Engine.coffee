parseOrder      = require './parseOrder'
describeOrder   = require './describeOrder'
Resolver        = require './Resolver'
RetreatResolver = require './RetreatResolver'

{english, outcomes, orders, paths} = require './enums'

{OVERLAND, OVERSEA}                = paths
{MOVE, SUPPORT, CONVOY, HOLD}      = orders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes

Engine = (board) ->
	self = {}
	phases = [
		SPRING = 0
		RETREAT = 1
		FALL = 2
		RETREAT
		WINTER = 3
	]
	phase = SPRING; year = 1901

	self.resolve = (orders, options) ->
		resolver = (
			switch phase
				when SPRING, FALL
					moveResolver
				when RETREAT
					retreatResolver
				when WINTER
					buildResolver
		) orders, TEST: false

		order.succeeds = resolver.resolve order for order in orders

		return orders

	parseOrders = (orders) -> parseOrder order for order in orders

	moveResolver = (orders, options) -> Resolver board, orders, options

	retreatResolver = (retreat_orders, options) ->
		RetreatResolver board, retreat_orders, options

	self.testMoves = (test_name, args...) ->
		orders = extractTestOrders args
		resolver = moveResolver orders, TEST: true
		dbg_resolver = moveResolver orders, DEBUG: true, TEST: true

		self.test test_name, orders, resolver, dbg_resolver

	self.testRetreats = (test_name, {moves, retreats}) ->
		moves = (parseOrder move for move in moves)
		# First resolve the moves.
		self.resolve moves

		# Build up the retreat orders and the resolver for them
		retreats = extractTestOrders retreats
		resolver = retreatResolver moves, retreats, TEST: true
		dbg_resolver = retreatResolver moves, retreats, DEBUG: true, TEST: true

		# Kick off the retreat tests
		self.test test_name, retreats, resolver, dbg_resolver

	self.test = (test_name, orders, resolver, dbg_resolver) ->
		console.log "Test: #{test_name}"

		for order in orders
			result = resolver.resolve order

			if result isnt order.expects
				console.log 'Test failed, rerunning in debug mode'
				delete order.succeeds
				# Running with the debug resolver which show the debug outputs.
				# Consider changing DEBUG to VERBOSE. Consider making options
				# lower cased.
				dbg_resolver.resolve order
				console.log 'Evaluated order: ', describeOrder order
				console.log "
					Expect: #{english outcomes, order.expects},
					Actual: #{english outcomes, result}
				"
				console.log "Test failed\n"
				return

		console.log "Test succeeded\n"

	# Takes arguments for a test case where each argument is an order followed
	# by an argument describing the expected outcome. Breaks this down and
	# returns a set of parsed orders where each has an expects property.
	extractTestOrders = (args) ->
		for arg,i in args by 2
			expect = args[i+1]; order = parseOrder arg
			Object.assign order, expects: expect

	# Apply resolved move orders and return an object with the number of
	# adjustments for each nation.
	self.adjust = (orders) ->
		# Only move orders can effect an adjustment and only when they are
		# successful.
		orders = orders.filter (o) ->
			o.type is 'MOVE' and
			o.succeeds is 'succeeds'

		for order in orders
			region = board.region order.to
			if region.supply_center
				throw new Error 'Not yet implemented'

	return self

module.exports = Engine
