holdStrength = (region) ->
	# If the region is empty or contains a unit that moved successfully then
	# hold strength is 0
	if not units[region]? or ordersWhere 'MOVE', {from: region}
		return 0
	# If a unit try to move from this region and failed then hold strength is 1.
	else if ordersWhere 'MOVE', {from: region}, {mustSucceed: false}
		return 1
	else
		# TODO: A unit cannot support itself to hold. Make sure this is
		# addressed in the map constraints.
		return 1 + ordersWhere('SUPPORT', from: region, to: region).length
