parseOrder      = require './parseOrder'
describeOrder   = require './describeOrder'
Resolver        = require './Resolver'
RetreatResolver = require './RetreatResolver'
BuildResolver   = require './BuildResolver'
StubBoard       = require './StubBoard'
Phase           = require './Phase'

{english, outcomes, orders: eorders, paths} = require './enums'

{OVERLAND, OVERSEA}                = paths
{MOVE, SUPPORT, CONVOY, HOLD}      = eorders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes

Engine = (board, pfinder, phase) ->
	self = {}
	phase = new Phase phase

	Object.defineProperty self, 'phase', enumerable: true, value: phase

	self.resolve = (orders, options, apply = false) ->
		orders = (parseOrder order for order in orders)

		resolver = (
			switch phase.season
				when 'Spring', 'Fall'
					moveResolver
				when 'Spring Retreat', 'Fall Retreat'
					retreatResolver
				when 'Winter'
					buildResolver
		) orders, TEST: false

		resolver.resolve order for order in orders

		if apply
			resolver.apply()

		return orders

	self.roll = (orders, options) ->


		# Resolve orders and apply them to the board.
		self.resolve orders, options, true

		# If the season was Spring or Fall then we're headed into the retreat
		# phase and we can auto resolve it if there are no dislodged units (but
		# we still must resolve it to know about the number of adjustments
		# needed for the next phase)
		if phase.season in ['Spring', 'Fall'] and board.dislodgedUnits().length is 0
			console.log "KICKOFF RETREAT RESOLVER"
			phase.inc()
			console.log "Inced phase: #{phase}"
			self.resolve [], options, true

		phase.inc()
		console.log "Inced phase: #{phase}"

		return

	parseOrders = (orders) -> parseOrder order for order in orders

	moveResolver = (orders, options) ->
		Resolver board, pfinder, orders, options

	retreatResolver = (orders, options) ->
		new RetreatResolver self, board, orders, options

	buildResolver = (orders, adjustments, options) ->
		BuildResolver StubBoard(board, adjustments), orders, options

	# Clear all of the existing units off of the board and set it up so that
	# each unit which was given an order is actually on the board.
	self.setUnitsForTest = (orders) ->
		board.clearUnits()
		for order in orders
			board.addUnit order.country,
				type: order.utype
				region: order.actor

	self.testMoves = (test_name, args...) ->
		orders = extractTestOrders args
		resolver = moveResolver orders, TEST: true
		dbg_resolver = moveResolver orders, DEBUG: true, TEST: true

		self.setUnitsForTest orders
		self.test test_name, orders, resolver, dbg_resolver

	self.testRetreats = (test_name, {moves, retreats}) ->
		# First resolve the moves.
		board.clearUnits()
		self.setUnitsForTest(parseOrder move for move in moves)
		self.apply moves
		retreats = extractTestOrders retreats

		# Build up the retreat orders and the resolver for them
		resolver = retreatResolver retreats, TEST: true
		dbg_resolver = retreatResolver retreats, DEBUG: true, TEST: true
		self.test test_name, retreats, resolver, dbg_resolver

	self.testBuilds = (test_name, adjustments, args...) ->
		orders = extractTestOrders args
		resolver = buildResolver orders, adjustments, TEST: true
		dbg_resolver = buildResolver orders, DEBUG: true, TEST: true

		self.test test_name, orders, resolver, dbg_resolver

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
