_ = require 'underscore'

describeOrder = require './describeOrder'

{english, outcomes, orders: eorders, paths} = require './enums'
{MOVE, SUPPORT, CONVOY, HOLD}      = eorders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes

class RetreatResolver
	board = null; orders = null

	constructor: (board, orders, options) ->
		# Filter out orders for units that weren't dislodged.
		orders = orders.filter (order) ->
			!! board.dislodgedUnits().find (u) ->
				order.actor is u.region and
				order.country is u.country.name and
				u.dislodger?

	resolve: (order) ->
		preventers = orders.filter (o) ->
			o.to is order.to and
			!_.isEqual(o, order) and
			canRetreat(o)

		if canRetreat(order) and preventers.length is 0
		# Find other retreat orders to the same destination. TODO: Make sure
		# the other retreat orders are to a valid destination.
			order.succeeds = SUCCEEDS
		else
			order.succeeds = FAILS

	apply: ->
		adjustments = {}

		for order in orders when order.succeeds is SUCCEEDS
			unit = board.region(order.actor).unit
			console.log "Retreating unit: ", unit.region
			board.moveUnit unit, order.to

		for order in orders when order.succeeds is FAILS
			console.log "Removing failed retreat: ", order.actor
			board.removeUnit order.actor

		# If this is the end of fall then we need to apply adjustments for
		# centers taken.
		if options.take_centers
			for unit in board.units() when \
			unit.region not in unit.country.supply_centers
				board.incAdjustments unit.country.name, 1
				taken_from = board.countries().find (c) -> unit.region in c.supply_centers
				board.incAdjustments taken_from, -1

	# Determine if an order can retreat to the area it's trying to retreat to.
	# This is separate from the resolver because before we fail an order for
	# retreating to the same destination as another one we have to make sure
	# that both retreat orders were valid.
	canRetreat = (order)->
		# Only move orders are allowed during retreat
		order.type is MOVE and
		order in orders and
		# We don't need to check for convoys during retreats so this should suffice.
		board.canMove(order) and
		# Try to retreat to the region of the unit that dislodged
		! board.dislodgedUnits().find(
			(u) -> u.region is order.actor and order.to is u.dislodger
		) and
		# Try to retreat to contested region
		! (board.region(order.to).contested ? false)

module.exports = RetreatResolver
