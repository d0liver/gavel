_ = require 'underscore'

describeOrder = require './describeOrder'

{english, outcomes, orders: eorders, paths} = require './enums'
{MOVE, SUPPORT, CONVOY, HOLD}      = eorders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes

RetreatResolver = (board, orders, options) ->
	self = {}

	# Filter out orders for units that weren't dislodged.
	orders = orders.filter (order) ->
		!! board.dislodgedUnits().find (u) ->
			order.actor is u.region and
			order.country is u.country.name and
			u.dislodger?

	self.resolve = (order) ->
		preventers = orders.filter (o) ->
			o.to is order.to and
			!_.isEqual(o, order) and
			canRetreat(o)

		if canRetreat(order) and preventers.length is 0
		# Find other retreat orders to the same destination. TODO: Make sure
		# the other retreat orders are to a valid destination.
			SUCCEEDS
		else
			FAILS

	# Determine if an order can retreat to the area it's trying to retreat to.
	# This is separate from the resolver because before we fail an order for
	# retreating to the same destination as another one we have to make sure
	# that both retreat orders were valid.
	canRetreat = (order)->
		# Only move orders are allowed during retreat
		order.type is MOVE and
		order in orders and
		# Try to retreat to the region of the unit that dislodged
		! board.dislodgedUnits().find(
			(u) -> u.region is order.actor and order.to is u.dislodger
		) and
		# Try to retreat to contested region
		! (board.region(order.to).contested ? false)

	return self

module.exports = RetreatResolver
