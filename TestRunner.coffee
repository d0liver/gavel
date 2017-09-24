_                                           = require 'underscore'
parseOrder                                  = require './parseOrder'
describeOrder                               = require './describeOrder'
{english, outcomes, orders: eorders, paths} = require './enums'

{OVERLAND, OVERSEA}                = paths
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes
{MOVE, SUPPORT, CONVOY, HOLD}      = eorders

MoveResolver    = require './resolvers/MoveResolver'
RetreatResolver = require './resolvers/RetreatResolver'
BuildResolver   = require './resolvers/BuildResolver'

opts = TEST: true
debug_opts = TEST: true, DEBUG: true

class TestRunner

	constructor: (@_engine, @_board, @_pfinder) ->

	moves: (test) ->
		orders = @_extractOrders test.orders

		args = [@_board, @_pfinder, orders]
		resolver = new MoveResolver args..., opts
		dbg_resolver = new MoveResolver args..., debug_opts

		@_setUnitsForTest orders
		@test test.description, orders, resolver, dbg_resolver

	retreats: (test) ->
		retreats = @_extractOrders test.retreats

		@_setUnitsForTest test.moves.map parseOrder
		@_engine.resolve test.moves, {TEST: true, DEBUG: true}, true

		args = [@, @_board, retreats]
		# Build up the retreat orders and the resolver for them
		resolver = new RetreatResolver args..., opts
		dbg_resolver = new RetreatResolver args..., debug_opts
		@test test.description, retreats, resolver, dbg_resolver

	builds: (test) ->
		orders = @_extractOrders test.orders
		resolver = new BuildResolver @_board, orders, opts
		dbg_resolver = new BuildResolver @_board, orders, debug_opts

		# Clear the starting game units off of the board.
		if test.setup?
			@_setUnitsForTest test.setup.map parseOrder
		else
			@_board.clearUnits()
		# Set up the adjustments on the @_board
		@_board.adjustments cname, adj for cname, adj of test.adjustments

		@test test.description, orders, resolver, dbg_resolver

		# Clean up adjustments after the fact
		@_board.adjustments cname, 0 for cname, adj of test.adjustments

	test: (description, orders, resolver, dbg_resolver) ->
		console.log description

		for order in orders
			result = resolver.resolve order

			if result isnt order.expect
				console.log 'Test failed, rerunning in debug mode'
				delete order.succeeds
				# Running with the debug resolver which show the debug outputs.
				# Consider changing DEBUG to VERBOSE. Consider making options
				# lower cased.
				dbg_resolver.resolve order
				console.log 'Evaluated order: ', describeOrder order
				console.log "
					Expect: #{english outcomes, order.expect},
					Actual: #{english outcomes, result}
				"
				console.log "Test failed\n"
				return

		console.log "Test succeeded\n"

	# Clear all of the existing units off of the board and set it up so that
	# each unit which was given an order is actually on the board.
	_setUnitsForTest: (orders) ->
		@_board.clearUnits()
		for order in orders
			@_board.addUnit order.country,
				type: order.utype
				region: order.actor

	_extractOrders: (orders)->
		orders.map (o) ->
			# Parse the order and append to it the enum representation of the
			# expected outcome (comes in as a string)
			Object.assign parseOrder(o.text), expect: outcomes[o.expect]

module.exports = TestRunner
