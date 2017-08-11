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

		# Only move orders are allowed during retreat
		if order.type isnt MOVE or
		# Find other retreat orders to the same destination. TODO: Make sure
		# the other retreat orders are to a valid destination.
		orders.find((o) -> o.to is order.to and !_.isEqual o, order) or
		order not in orders or
		# Try to retreat to the region of the unit that dislodged
		board.dislodgedUnits().find((u) -> u.region is order.actor and order.to is u.dislodger) or
		# Try to retreat to contested region
		board.region(order.to).contested ? false
			FAILS
		else
			SUCCEEDS

	return self

module.exports = RetreatResolver
