# 3rd Party
_ = require 'underscore'

# Local
CycleGuard       = require './CycleGuard'
{CycleException} = require './Exceptions'
utils            = require './utils'
debug            = require('./debug') 'Resolver'

# Adapted from "The Math of Adjudication" by Lucas Kruijswijk
# We assume in the resolver that the map constraints have been satisfied (moves
# are to valid locations, etc.)
Resolver = (board, orders, TEST = false) ->
	self = {}

	self.resolve = (order) ->
		try
			order.succeeds = self.adjudicate order
		catch err
			if err instanceof CycleException
				order.succeeds = handleCycle err
			else
				throw err

	succ = (result) -> (result and 'SUCCEEDS') or (! result and 'FAILS')

	# nr - The number of the order to be resolved.
	# Returns the resolution for that order.
	self.adjudicate = (order) ->

		# This needs to be here and not in the call to resolve because
		# adjudicate can be called internally and we still want the ILLEGAL
		# resolution in those cases.
		valid_region = board.region(order.actor)?.unit?.type is order.utype
		hop_move = order.from is order.to
		# Determine whether or not the destination region has coasts
		no_coast = Object.keys(board.region(order.to)?.coasts ? {}).length is 0
		# If the destination has coasts then we _must_ specify one or the order
		# is illegal. If it ends up that we can't actually move to a coast then
		# hasPath will return false and the order will fail but we're not
		# considering it illegal.
		specified_coast = order.type isnt 'MOVE' or no_coast or order?.to_coast?

		unless (valid_region or TEST) and not hop_move and specified_coast
			return 'ILLEGAL'

		switch order.type
			when 'MOVE'
				# Preflight checks. Coast must be specified if the region has
				# coasts. We must have a path to the destination.
				return 'FAILS' unless hasPath order

				# Get the largest prevent strength
				preventers = ordersWhere(order, 'MOVE', 'EXISTS', to: order.to) ? []

				prevent_strength = preventers.reduce (max, preventer) ->
					Math.max max, preventStrength preventer
				, 0

				attack_strength = attackStrength(order)
				[opposing_order] = ordersWhere(order, 'MOVE', 'EXISTS',
					to: order.from
					from: order.to
				) ? []

				hold_strength = holdStrength(order.to)

				# This stuff is useful but debug needs to take a flag
				# debug "OPPOSING ORDER: ", opposing_order
				# debug "ATTACK: ", attack_strength
				# debug "PREVENT: ", prevent_strength
				# debug "HOLD: ", hold_strength
				# if opposing_order
				# 	debug "DEFEND: ", defendStrength(opposing_order)

				return succ attack_strength > prevent_strength and (
					(
						opposing_order? and
						attack_strength > defendStrength(opposing_order)
					) or
					attack_strength > hold_strength
				)

			when 'SUPPORT'

				# Support can only be into an adjacent region
				unless (
					# Indicates a support hold order
					!order.to? or
					areAdjacent order.utype, order.actor, order.to
				) and order.actor isnt order.from
					return 'ILLEGAL'

				# If there is a move order moving to the unit that is supporting
				# that is not the destination of the support (you can't cut a
				# support that's supporting directly against you) then the support
				# will be cut (even when the move order failed)
				return succ ! ordersWhere order, 'MOVE', 'EXISTS',
					to: order.actor
					from: (f) ->
						f isnt order.to
					country: (c) -> c isnt order.country

			when 'CONVOY'
				# A convoy succeeds when it's not dislodged. We know that we can't
				# move and convoy at the same time so it's sufficient to check if
				# there was a successful move to the convoyer.
				return succ ! ordersWhere order, 'MOVE', 'SUCCEEDS', to: order.actor
			when 'HOLD'
				# Same thing with convoy and hold orders (see above)
				return succ ! ordersWhere order, 'MOVE', 'SUCCEEDS', to: order.actor

	# Uses the board adjacencies to determine if an order can move
	areAdjacent = (type, from, to, coast = null) ->

		adjacencies = board.adjacencies from, to, coast

		if type is 'Fleet'
			types = _.intersection adjacencies, ['xc', 'sc', 'nc', 'ec', 'wc']
			types.length isnt 0 and (!coast? or coast in types)
		else if type is 'Army'
			'mv' in adjacencies


	# Check if _from_ is adjacent to _to_ or for successful convoy orders
	# allowing _unit_ to move from _from_ to _to_.
	hasPath = (order) ->

		corders = ordersWhere null, 'CONVOY', 'SUCCEEDS', _.pick order, 'from', 'to'
		{utype, from, to, to_coast} = order
		# Check if there's a valid immediately adjacent region
		if areAdjacent utype, from, to, to_coast
			return true
		# _hasPath is for figuring out convoy routes which can only happen if
		# the unit is an army and the destination is land.
		else unless order.utype is 'Army' and board.region(order.to).type is 'Land'
			return false

		return _hasPath order.from, order.to, corders

	_hasPath = (from, dest, corders) ->

		# We have a _from_ connected to the destination so this is the end of
		# the convoy and we are finished.
		if board.adjacency(from, dest)
			return true

		# We don't have a complete path yet, so we have to keep looking for
		# convoys that can get us there.
		next_hops = (
			order for order in corders ? [] when \
			board.adjacency(from, order.actor) is 'xc'
		)

		# Convoy paths can fork but _.some guarantees that __some__ path to the
		# destination exists.
		return _.some(_hasPath hop.actor, dest, corders for hop in next_hops)

	holdStrength = (region) ->
		region_has_units = !! orders.find (o) -> o.actor is region
		# If the region started empty or contains a unit that moved
		# successfully then hold strength is 0
		if !region_has_units or ordersWhere(null, 'MOVE', 'SUCCEEDS', from: region)
			return 0
		# If a unit tried to move from this region and failed then hold strength is
		# 1.
		else if !! ordersWhere(null, 'MOVE', 'FAILS', from: region)
			return 1
		else
			supports = ordersWhere 'SUPPORT', 'SUCCEEDS', from: region, type: 'HOLD'

			return 1 + (supports?.length ? 0)

	attackStrength = (order) ->
		oW = ordersWhere.bind null, order
		# TODO: This needs review
		res = oW 'MOVE', 'SUCCEEDS', from: order.to
		dest_order = res?[0]

		if not board.region(order.to)?.unit? or
		dest_order? and dest_order.to isnt order.from
			return 1 + support(order)
		else if board.region(order.to).unit?.country is order.country
			# We can't dislodge our own units
			return 0
		else
			# Head to head battle. The attack strength is now 1 plus the number of
			# supporting units (but units can't support against their own).
			{from, to} = order
			val = 1 + (oW(
				'SUPPORT', 'SUCCEEDS', {from, to},
				country: (c) ->
					c isnt board.region(order.to).unit?.country
			)?.length ? 0)
			return val

	defendStrength = (order) ->
		return 1 + support(order)

	preventStrength = (order) ->
		# For a head to head battle where the other side was successful our
		# strength is 0
		if ordersWhere(order, 'MOVE', 'SUCCEEDS', to: order.from)
			return 0
		else
			return 1 + support(order)

	# Get the number of supports for an order
	support = (order) ->
		{from, to} = order
		return ordersWhere(order, 'SUPPORT', 'SUCCEEDS', {from, to})?.length ? 0

	ordersWhere = (current, type, requires, matches) ->
		results = []
		`outer: //`
		for order in orders when order.type is type and ! _.isEqual order, current
			for key, value of matches
				# Check if the order values match the key value pairs given in the
				# matches or if a function was provided instead of a value then
				# evaluate that function as a filter on the given key (slightly
				# confusing but the actual usage is intuitive and handy).
				if (typeof value isnt "function" and order[key] isnt value) or
				typeof value is "function" and not value(order[key])
					`continue outer`

			# In some cases we only care if an order exists. Therefore, if _exists_
			# is true then we return the order simply because we found it. Other
			# times, we care specifically if the order succeeded or failed. In
			# these cases one can set _succeeds_ and only orders which match that
			# criterion will be returned.
			result = self.adjudicate order
			if result isnt 'ILLEGAL' and
			(requires is 'EXISTS' or result is requires)
				results.push order

		# This makes it so that we can use the results as a boolean or use the
		# actual results which is convenient.
		return results if results?.length

	self.describe = (order) ->

		region = (order) -> board.region order.actor
		dscr = switch order.type
			when 'CONVOY' then "
				#{order.country}'s Fleet in
				#{order.actor} convoys #{order.from} to #{order.to}
			"
			when 'SUPPORT' then "
				#{order.country}'s
				#{order.utype} in #{order.actor} supports
				#{order.utype} in #{order.from} to #{order.to}
			"
			when 'MOVE' then "
				#{order.country}'s
				#{order.utype} in #{order.from} moves to #{order.to}
			"
		return dscr + "#{pad(order.succeeds, ' ')}"

	showResult = (status) ->
		debug "ORDER ", status

	pad = (str, end = '') -> str and "#{end or ' '}#{str}#{end}" or '' 

	handleCycle = ({cycle}) ->

		debug 'FIRST'
		first = cycle.replay 'SUCCEEDS'

		debug 'SECOND'
		second = cycle.replay 'FAILS'

		# Same result so it doesn't matter which decision we use.
		if first is second
			debug 'CONSISTENT OUTCOME'
			cycle.remember(first)
			return first
		else
			# We achieved different outcomes so there is some symmetric cycle
			# at work and we need a fallback rule to adjudicate.
			return cycle.replay(fallback(cycle))

	fallback = (cycle) ->
		throw new Error "Fallback not implemented"

	self.adjudicate = CycleGuard(self.adjudicate, handleCycle).fork()

	return self

module.exports = Resolver
