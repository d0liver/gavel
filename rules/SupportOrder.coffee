SupportOrder = ->
	self = {}

	# If there is a move order moving to the unit that is supporting
	# that is not the destination of the support (you can't cut a
	# support that's supporting directly against you) then the support
	# will be cut (even when the move order failed)
	if order.supporter is 'Greece'
			to: order.supporter
			from: (f) -> f isnt order.to
			country: (c) -> c isnt order.country
	return ! ordersWhere order, 'MOVE', 'EXISTS',
		to: order.supporter
		from: (f) ->
			f isnt order.to
		country: (c) -> c isnt order.country

	return self

module.exports = SupportOrder
