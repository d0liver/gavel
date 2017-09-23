_ = require 'underscore'

describeOrder = require '../describeOrder'

{english, outcomes, orders: eorders, paths} = require '../enums'
{MOVE, SUPPORT, CONVOY, HOLD}      = eorders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes

class RetreatResolver
	constructor: (@_engine, @_board, @_orders, @_options) ->
		console.log "@_orders: ", @_orders
		# Filter out orders for units that weren't dislodged.
		@_orders = @_orders.filter (order) =>
			!! @_board.dislodgedUnits().find (u) ->
				order.actor is u.region and
				order.country is u.country.name and
				u.dislodger?

	resolve: (order) ->
		preventers = @_orders.filter (o) ->
			o.to is order.to and
			!_.isEqual(o, order) and
			@_canRetreat(o)

		if @_canRetreat(order) and preventers.length is 0
		# Find other retreat orders to the same destination. TODO: Make sure
		# the other retreat orders are to a valid destination.
			order.succeeds = SUCCEEDS
		else
			order.succeeds = FAILS

	apply: ->
		adjustments = {}

		for order in @_orders when order.succeeds is SUCCEEDS
			unit = @_board.region(order.actor).unit
			console.log "Retreating unit: ", unit.region
			@_board.moveUnit unit, order.to

		for order in @_orders when order.succeeds is FAILS
			console.log "Removing failed retreat: ", order.actor
			@_board.removeUnit order.actor

		console.log "Attempting to apply adjustments..."
		console.log "SUPPLY CENTERS: ", @_board.supplyCenters()
		# If this is the end of fall then we need to apply adjustments for
		# centers taken.
		if @_engine.phase.season is 'Fall Retreat'
			for unit in @_board.units() when \
			unit.region in @_board.supplyCenters() and
			unit.region not in unit.country.supply_centers
				@_board.adjust unit.country.name, 1
				taken_from = @_board.countries().find (c) ->
					unit.region in c.supply_centers

				@_board.adjust taken_from.name, -1 if taken_from?

	# Determine if an order can retreat to the area it's trying to retreat to.
	# This is separate from the resolver because before we fail an order for
	# retreating to the same destination as another one we have to make sure
	# that both retreat orders were valid.
	_canRetreat: (order) ->
		console.log "Orders? ", @_orders
		# Only move orders are allowed during retreat
		order.type is MOVE and
		order in @_orders and
		# We don't need to check for convoys during retreats so this should suffice.
		@_board.canMove(order) and
		# Try to retreat to the region of the unit that dislodged
		! @_board.dislodgedUnits().find(
			(u) -> u.region is order.actor and order.to is u.dislodger
		) and
		# Try to retreat to contested region
		! (@_board.region(order.to).contested ? false)

module.exports = RetreatResolver
