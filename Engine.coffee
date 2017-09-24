parseOrder      = require './parseOrder'
describeOrder   = require './describeOrder'

Phase           = require './Phase'

MoveResolver    = require './resolvers/MoveResolver'
RetreatResolver = require './resolvers/RetreatResolver'
BuildResolver   = require './resolvers/BuildResolver'

Engine = (board, pfinder, phase) ->
	self = {}
	phase = new Phase phase

	Object.defineProperty self, 'phase', enumerable: true, value: phase

	self.resolve = (orders, options, apply = false) ->
		orders = (parseOrder order for order in orders)

		opts = TEST: false

		resolver =
			switch phase.season
				when 'Spring', 'Fall'
					console.log "USE MOVE RESOLVER"
					new MoveResolver board, pfinder, orders, opts
				when 'Spring Retreat', 'Fall Retreat'
					new RetreatResolver self, board, orders, opts
				when 'Winter'
					new BuildResolver board, orders, opts

		resolver.resolve order for order in orders

		resolver.apply() if apply

		return orders

	self.roll = (orders, options) ->

		console.log "Roll phase: #{phase}"

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
