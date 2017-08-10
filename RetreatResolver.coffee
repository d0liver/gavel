_ = require 'underscore'

describeOrder = require './describeOrder'

{english, outcomes, orders: eorders, paths} = require './enums'
{MOVE, SUPPORT, CONVOY, HOLD}      = eorders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes

RetreatResolver = (board, orders, options) ->
	self = {}

	self.resolve = (order) ->
		# Only move orders are allowed during retreat
		FAILS if order.type isnt MOVE

		# Find other retreat orders to the same destination. TODO: Make sure
		# the other retreat orders are to a valid destination.
		FAILS if orders.find (o) -> o.to is order.to

	return self

module.exports = RetreatResolver
