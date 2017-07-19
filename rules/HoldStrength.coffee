HoldStrength = (region) ->
	# If the region is empty or contains a unit that moved successfully then
	# hold strength is 0
	if not units[region]? or oW('MOVE', 'SUCCEEDS', from: region)
		return 0
	# If a unit tried to move from this region and failed then hold strength is
	# 1.
	else if !! oW('MOVE', 'FAILS', from: region)
		return 1
	else
		# TODO: A unit cannot support itself to hold. Make sure this is
		# addressed in the map constraints.
		return 1 + (oW('SUPPORT', 'SUCCEEDS', from: region, to: region)?.length ? 0)

module.exports = HoldStrength
