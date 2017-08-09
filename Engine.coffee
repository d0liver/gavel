parseOrder    = require './parseOrder'
describeOrder = require './describeOrder'
Resolver      = require './Resolver'

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
		) orders, options

		order.succeeds = resolve order for order in orders

		return orders

	parseOrders = (orders) -> parseOrder order for order in orders

	moveResolver = (orders, options) -> Resolver board, orders, options

	self.testMoves = (test_name, args...) ->
		console.log "Test: #{test_name}"

		# Attach the expected value to each parsed order as 'expects'. Expected
		# values come after the unparsed order.
		orders = for arg,i in args by 2
			expect = args[i+1]; order = parseOrder arg
			Object.assign order, expects: expect

		resolver = moveResolver orders, TEST: true
		dbg_resolver = moveResolver orders, DEBUG: true, TEST: true

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
				console.log "Expect: #{order.expects}, Actual: #{result}"
				console.log "Test failed\n"
				return

	self.testRetreat = (test_name, {moves, retreats}) ->

		console.log "Test succeeded\n"

	return self

module.exports = Engine
