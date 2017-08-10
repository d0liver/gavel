_ = require 'underscore'

RetreatResolver = (retreat_orders, options) ->
	self = {}

	self.resolve = (order) ->
		# # If this unit retreats to the same space as another one then it fails
		# # and is destroyed.
		# if (retreat_orders.filter (o) -> o.to is order.to).length > 1 or
		# retreat_orders.find (o) -> o.actor is order.to
		# 	order.succeeds = 'DESTROY'
		# else
		# 	# Retreats succeed by default
		# 	order.succeeds = 'SUCCEEDS'

		# return order

	return self

module.exports = RetreatResolver
