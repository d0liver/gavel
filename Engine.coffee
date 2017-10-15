parseOrder      = require './parseOrder'
describeOrder   = require './describeOrder'

Phase      = require './Phase'
Board      = require './Board'
PathFinder = require './PathFinder'

MoveResolver    = require './resolvers/MoveResolver'
MoveValidator   = require './validators/MoveValidator.coffee'
RetreatResolver = require './resolvers/RetreatResolver'
BuildResolver   = require './resolvers/BuildResolver'

class Engine
	constructor: (gdata, vdata) ->
		@_board   = Board gdata, vdata
		@_pfinder = new PathFinder @_board
		@_phase   = new Phase gdata.phase.season_year

		Object.defineProperty @, 'phase', enumerable: true, value: @_phase
		Object.defineProperty @, 'board', value: @_board
		Object.defineProperty @, 'pfinder', value: @_pfinder
		Object.defineProperty @, 'country',
			get: -> @_country
			set: (c) ->
				cnames = (country.name for country in gdata.phase.countries)

				if c in cnames
					@_country = c
				else
					throw new Error "Tried to set invalid country: #{c}"

	resolve: (orders, options, apply = false) ->
		orders = (parseOrder order for order in orders)

		opts = TEST: false

		resolver =
			switch @_phase.season
				when 'Spring', 'Fall'
					console.log "USE MOVE RESOLVER"
					new MoveResolver @_board, @_pfinder, orders, opts
				when 'Spring Retreat', 'Fall Retreat'
					new RetreatResolver @, @_board, orders, opts
				when 'Winter'
					new BuildResolver @_board, orders, opts

		resolver.resolve order for order in orders

		resolver.apply() if apply

		return orders

	roll: (orders, options) ->

		console.log "Roll phase: #{@_phase}"

		# Resolve orders and apply them to the @_board.
		@resolve orders, options, true

		# If the season was Spring or Fall then we're headed into the retreat
		# phase and we can auto resolve it if there are no dislodged units (but
		# we still must resolve it to know about the number of adjustments
		# needed for the next phase)
		if @_phase.season in ['Spring', 'Fall'] and @_board.dislodgedUnits().length is 0
			console.log "KICKOFF RETREAT RESOLVER"
			@_phase.inc()
			console.log "Inced phase: #{@_phase}"
			@resolve [], options, true

		@_phase.inc()
		console.log "Inced phase: #{@_phase}"

		return

	isLegal: (order, country = null) ->
		validator = switch @_phase.season
			when 'Spring', 'Fall'
				new MoveValidator @_board, @_pfinder
			when 'Spring Retreat', 'Fall Retreat'
				throw new Error 'Retreat validator not yet implemented'
			when 'Winter'
				throw new Error 'Build validator not yet implemented'

		if country? or @_country?
			validator.isLegal order, (country or @_country)
		else
			throw new Error '
				No country was specified while validating an order. A country
				name should be passed as an argument to engine.isLegal or set
				on the engine itself, i.e., engine.country = "MyCountry".
			'

module.exports = Engine
