{ResolverException} = require './CustomExceptions'

Engine = ({countries, regions}, player_country_name, Resolver) ->
	self = {}

	# Orders are keyed by their acting unit for easier/faster lookup
	# (e.g. the unit moving, the unit supporting, the unit convoying)
	orders = {}

	self.resolve = ->
		console.log "Attempting to resolve orders..."
		# First, we have to build up a units object in the format expected by
		# the resolver.
		units = {}
		for country in countries
			for unit in country.units
				units[unit.region] = unit.type
		console.log "Resolver units: ", units

		try
			self.checkMapConstraints()
		resolver = Resolver orders, units
		# resolver.resolve()

	return self

module.exports = Engine
