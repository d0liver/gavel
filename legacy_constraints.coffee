# All of the map constraints are moving to the resolver itself. I'm keeping
# these around for a minute so that I can use them to model the ones in the
# adjudicator.

self.canMove = (from, to) ->

	# Check and make sure that we don't have another unit moving to that
	# space already.
	for actor,order of orders when order.type is 'MOVE' and order.to is to
		return false

	# If we can support there and we don't already have a unit there then
	# we can move there.
	unless self.canSupport(from, to)
		return false

	return true

self.hasOrder = (unit) -> !! orders[unit.region]

self.playerOwns = (region) ->
	for unit in player_country.units when unit.region is region
		return true

	return false

# Check and make sure all of the orders that have been added so far are valid
# according to the map constraints.
self.checkMapConstraints = ->
	for actor,order of orders
		if order.type is 'MOVE' and not self.canMove(order.from, order.to)
			msg = "Illegal order from #{order.from} to #{order.to}"
			throw new ResolverException(msg)

self.canSupport = (supporter, to) ->
	# Get the supporting unit
	unit = self.regionUnit supporter
	self.isAdjacent(supporter, to)
