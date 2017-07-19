DefendStrength = (order) ->
	return 1 + exports.support(order)

module.exports = DefendStrength
