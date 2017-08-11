{english, outcomes, orders: eorders, paths} = require './enums'
{MOVE, SUPPORT, CONVOY, HOLD, BUILD}      = eorders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes

BuildResolver = (board, orders, options) ->
	self = {}
	# Get the number of adjustments from the board which will be modified as
	# they are used.
	adjustments = board.adjustments()

	self.resolve = (order) ->

		if adjustments[order.country] < 1 or
		board.region(order.region).type is 'Land' and order.utype is 'Fleet' or
		# Region is occupied so we cannot build there
		board.region(order.region).unit? or
		# Must build in a home center for our country
		order.region not in board.homeCenters(order.country) or
		# There can only be one build order for each home center. For now, I'll
		# let all of these orders fail. It really shouldn't happen because the
		# UI should protect against it. If it does then there's likely
		# something fishy going on anyway.
		orders.filter((o) -> o.region is order.region).length isnt 1
			return FAILS

		console.log "Attempt build resolve"

		if order.type is BUILD
			adjustments[order.country]--

		SUCCEEDS

	self.apply = ->

	return self

module.exports = BuildResolver
