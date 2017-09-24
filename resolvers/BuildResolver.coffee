{english, outcomes, orders: eorders, paths} = require '../enums'
{MOVE, SUPPORT, CONVOY, HOLD, BUILD}        = eorders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS}          = outcomes

class BuildResolver
	constructor: (@_board, @_orders) ->

	resolve: (order) ->

		region = @_board.region order.region

		return FAILS if @_board.adjustments(order.country) < 1 or
		region.type is 'Land' and order.utype is 'Fleet' or
		# Region is occupied so we cannot build there
		region.unit? or
		# Must build in a home center for our country
		order.region not in @_board.homeCenters(order.country) or
		# There can only be one build order for each home center. For now, I'll
		# let all of these orders fail. It really shouldn't happen because the
		# UI should protect against it. If it does then there's likely
		# something fishy going on anyway.
		@_orders.filter((o) -> o.region is order.region).length isnt 1 or
		order.type isnt BUILD

		@_board.addUnit order.country, type: order.utype, region: order.actor
		@_board.adjust order.country, -1

		SUCCEEDS

	apply: ->
		# XXX: Builds are always applied to the board. It probably makes sense
		# to just make the other resolvers work this way also.

module.exports = BuildResolver
