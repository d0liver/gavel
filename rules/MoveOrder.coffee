MoveOrder = ->
	self = {}

	# Get the largest prevent strength
	preventers = ordersWhere(order, 'MOVE', 'EXISTS', to: order.to) or []

	prevent_strength = preventers.reduce (max, preventer) ->
		Math.max max, preventStrength preventer
	, 0

	attack_strength = attackStrength(order)
	[opposing_order] = ordersWhere(order, 'MOVE', 'EXISTS',
		to: order.from
		from: order.to
	) ? []

	hold_strength = holdStrength(order.to)

	if DEBUG
		console.log "OPPOSING ORDER: ", opposing_order
		console.log "ATTACK: ", attack_strength
		console.log "PREVENT: ", prevent_strength
		console.log "HOLD: ", hold_strength
		if opposing_order
			console.log "DEFEND: ", defendStrength(opposing_order)

	return attack_strength > prevent_strength and (
		(
			opposing_order? and
			attack_strength > defendStrength(opposing_order)
		) or
		attack_strength > hold_strength
	)

	return self

module.exports = MoveOrder
