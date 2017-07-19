ConvoyOrder = ->
	self = {}

	# A convoy succeeds when it's not dislodged. We know that we can't
	# move and convoy at the same time so it's sufficient to check if
	# there was a successful move to the convoyer.
	return ! ordersWhere order, 'MOVE', 'SUCCEEDS', to: order.convoyer

	return self

module.exports = ConvoyOrder
