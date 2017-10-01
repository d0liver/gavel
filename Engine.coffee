parseOrder      = require './parseOrder'
describeOrder   = require './describeOrder'

Phase           = require './Phase'

MoveResolver    = require './resolvers/MoveResolver'
MoveValidator   = require './validators/MoveValidator.coffee'
RetreatResolver = require './resolvers/RetreatResolver'
BuildResolver   = require './resolvers/BuildResolver'

class Engine
	constructor: (@board, @pfinder, phase) ->
		@_phase = new Phase @_phase

		Object.defineProperty @, 'phase', enumerable: true, value: @_phase

	resolve: (orders, options, apply = false) ->
		orders = (parseOrder order for order in orders)

		opts = TEST: false

		resolver =
			switch @_phase.season
				when 'Spring', 'Fall'
					console.log "USE MOVE RESOLVER"
					new MoveResolver @board, @pfinder, orders, opts
				when 'Spring Retreat', 'Fall Retreat'
					new RetreatResolver @, @board, orders, opts
				when 'Winter'
					new BuildResolver @board, orders, opts

		resolver.resolve order for order in orders

		resolver.apply() if apply

		return orders

	roll: (orders, options) ->

		console.log "Roll phase: #{@_phase}"

		# Resolve orders and apply them to the @board.
		@resolve orders, options, true

		# If the season was Spring or Fall then we're headed into the retreat
		# phase and we can auto resolve it if there are no dislodged units (but
		# we still must resolve it to know about the number of adjustments
		# needed for the next phase)
		if @_phase.season in ['Spring', 'Fall'] and @board.dislodgedUnits().length is 0
			console.log "KICKOFF RETREAT RESOLVER"
			@_phase.inc()
			console.log "Inced phase: #{@_phase}"
			@resolve [], options, true

		@_phase.inc()
		console.log "Inced phase: #{@_phase}"

		return

module.exports = Engine
