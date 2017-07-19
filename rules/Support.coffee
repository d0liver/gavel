# Get the number of supports for an order
Support = (order) ->
	{from, to} = order
	return oW(order, 'SUPPORT', 'SUCCEEDS', {from, to})?.length ? 0

module.exports = Support
