PreventStrength = (order) ->
	# TODO: Check and see if the path was successful.
	# For a head to head battle where the other side was successful our
	# strength is 0
	if oW(order, 'MOVE', 'SUCCEEDS', to: order.from)
		return 0
	else
		return 1 + exports.support(order)

module.exports = PreventStrength
