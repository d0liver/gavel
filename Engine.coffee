Engine = ({countries, regions}, player_country_name, resolver) ->
	console.log "Player country name: ", player_country_name
	self = {}
	# Orders are keyed by their acting unit for easier/faster lookup (e.g. the
	# unit moving, the unit supporting, the unit convoying)
	orders = {}
	player_country = do ->
		for country in countries when country.name is player_country_name
			return country

	# From and to are region names
	self.addMove = (from, to) ->
		orders[from] = Object.assign {}, type: 'MOVE', {from, to}

	self.addSupport = (supporter, from, to) ->
		orders[supporter] = Object.assign {}, type: 'SUPPORT', {supporter, from, to}

	self.canSupport = (supporter, to) ->
		# Get the supporting unit
		unit = self.regionUnit supporter
		{adjacencies} = regions[supporter]

		for adj in adjacencies when adj.region is to
			# Currently we're ignoring coastal specific adjacencies
			return \
				adj.type is 'xc' and unit.type is 'Fleet' or
				adj.type is 'mv' and unit.type is 'Army'

	# _from_ and _to_ are region names
	self.canMove = (from, to) ->

		# Check and make sure that we don't have another unit moving to that
		# space already.
		for actor,order of orders when order.type is 'MOVE' and order.to is to
			return false

		# If we can support there and we don't already have a unit there then
		# we can move there.
		unless self.canSupport from, to
			return false

		return true

	self.hasOrder = (unit) -> !! orders[unit.region]

	self.playerOwns = (region) ->
		for unit in player_country.units when unit.region is region
			return true

		return false

	self.orders = -> Object.values orders

	self.regionUnit = (rname) ->
		region = regions[rname]
		for {units} in countries
			for unit in units when unit.region is rname
				return unit

	self.resolve = -> resolver.resolve()

	return self

module.exports = Engine
