parseOrder    = require './parseOrder'
describeOrder = require './describeOrder'

enums         = require './enums'

class Order

	constructor: (ord, @_engine) ->

		# This could be a littler cleaner looking but it is what we want so -
		# meh.
		{
			actor        : @_actor
			actor_coast  : @_actor_coast
			country      : @_country
			from         : @_from
			from_coast   : @_from_coast
			from_utype   : @_from_utype
			region       : @_region
			region_coast : @_region_coast
			to           : @_to
			to_coast     : @_to_coast
			type         : @_type
			utype        : @_utype
			via_convoy   : @_via_convoy
		} = ord

		# Make all of these public and read-only
		Object.defineProperties @,
			actor        : value : @_actor
			actor_coast  : value : @_actor_coast
			country      : value : @_country
			from         : value : @_from
			from_coast   : value : @_from_coast
			from_utype   : value : @_from_utype
			region       : value : @_region
			region_coast : value : @_region_coast
			to           : value : @_to
			to_coast     : value : @_to_coast
			type         : value : @_type
			utype        : value : @_utype
			via_convoy   : value : @_via_convoy
			hasPath      : get   : -> @_engine.pfinder.hasPath(@)?
			isLegal      : get   : -> @_engine.isLegal @

		# Orders are immutable - there shouldn't be any reason to make changes
		# once they're setup.
		Object.freeze @

	typeIs: (typ) -> enums.typeIs typ, @_type

	@from = (ord, engine) ->
		# Create a new order from order text if necessary, otherwise just use
		# the given order (convenient for using order text and order objects
		# interchangeably)
		if typeof ord is 'string'
			new Order parseOrder(ord), engine
		else
			ord

	@describe = describeOrder

module.exports = Order
