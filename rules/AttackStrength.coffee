AttackStrength = (engine, order) ->
	res = engine.ordersWhere 'MOVE', 'SUCCEEDS', {from: order.to}
	dest_order =
		if res?.length is 1
			res[0]
		else
			undefined

	if (not units[order.to]?) or (dest_order? and dest_order.to isnt order.from)
		return 1 + exports.support order
	else if units[order.to]?.country is order.country
		# We can't dislodge our own units
		return 0
	else
		# Head to head battle. The attack strength is now 1 plus the number of
		# supporting units (but units can't support against their own).
		{from, to} = order
		val = 1 + (engine.ordersWhere(
			'SUPPORT', 'SUCCEEDS', {from, to},
			country: (c) ->
				c isnt units[order.to]?.country
		)?.length ? 0)
		return val

module.exports = AttackStrength
