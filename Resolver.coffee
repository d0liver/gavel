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
				order.succeeds = handleCycle err, order
			else
				throw err

	succ = (result) -> (result and 'SUCCEEDS') or (! result and 'FAILS')

	# nr - The number of the order to be resolved.
	# Returns the resolution for that order.
	self.adjudicate = (order) ->

		# If we already have a resolution then we just spit that out. Normally
		# memoization would prevent this from happening but breakCycles will
		# insert its own resolutions from time to time that occur outside of
		# the normal adjudication process.
		return order.succeeds if order.succeeds?

		# This needs to be here and not in the call to resolve because
		# adjudicate can be called internally and we still want the ILLEGAL
		# resolution in those cases.
		valid_region = board.region(order.actor)?.unit?.type is order.utype
		hop_move = order.from is order.to
		# Determine whether or not the destination region has coasts
		no_coast = Object.keys(board.region(order.to)?.coasts ? {}).length is 0
		# TODO: If a fleet doesn't specify a coast then the order will simply
		# fail because the adjacencies are set on the coasts and not the
		# region. We probably need to consider getting rid of the 'ILLEGAL'
		# result and just returning fails because ILLEGAL can get really
		# complicated.
		# If the destination has coasts then we _must_ specify one or the order
		# is illegal. If it ends up that we can't actually move to a coast then
		# hasPath will return false and the order will fail but we're not
		# considering it illegal.
		specified_coast = order.type isnt 'MOVE' or no_coast or order?.to_coast?

		unless (valid_region or TEST) and not hop_move
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
				# console.log "Hold strength: ", hold_strength

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
					board.canSupport order
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

			when 'CONVOY', 'HOLD'
				# A convoy succeeds when it's not dislodged. We know that we can't
				# move and convoy at the same time so it's sufficient to check if
				# there was a successful move to the convoyer.
				return succ ! ordersWhere null, 'MOVE', 'SUCCEEDS', to: order.actor

	hasPath = ({utype, from, to, from_coast, to_coast})->

		# We have a _from_ connected directly to the _to_. This is the normal
		# case where convoys don't come into play.
		if board.canMove {utype, from, to, from_coast, to_coast}
			return true
		# Convoys are valid when it's an army being convoyed and the
		# destination is on land.
		else if utype is 'Army' and board.region(to).type is 'Land'
			corders = ordersWhere null, 'CONVOY', 'SUCCEEDS', {from, to}
			return hasConvoyPath {from, to}, corders

	hasConvoyPath = ({from, to}, corders, visited = []) ->

		return true if board.canConvoy {convoyer: from, convoyee: to}

		# We don't have a complete path yet, so we have to keep looking for
		# convoys that can get us there.
		next_hops = (
			cord for cord in corders ? [] when \
			cord.actor not in visited and
			board.canConvoy {
				convoyee: from
				convoyer: cord.actor
			}
		)

		# We need to make a note that we've been to this order so that we don't
		# end up circling between two regions which are both convoying.
		visited.push from

		# Convoy paths can fork but _.some guarantees that __some__ path to the
		# destination exists.
		return _.some(
			for hop in next_hops
				hasConvoyPath {from: hop.actor, to}, corders, visited
		)

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

	# This corresponds to the fallbacks that are discussed in MOA. The
	# difference is that we just go ahead and address these first so that we
	# don't have to readjudicate afterwards. Anything not handled preemptively
	# by this should be handleable by the handleCycle method.
	breakCycles = ->
		breakCircularMovement()

	breakCircularMovement = (order) ->
		# Obviously circular movements can only occur when the order itself is
		# a move
		return false if order.type isnt 'MOVE'

		# List of moves that have been seen so far in this chain
		chain = []
		morders = _.where orders, type: 'MOVE'

		while order? and order.from not in chain and !order.succeeds?
			chain.push order.from
			order = morders.find (o) -> order.from is o.to

		# If order was defined then that means that we broke out of the
		# loop because a cycle was detected (otherwise we would hit the end
		# of the chain). In that case, we want to resolve our order with a
		# success to break the cycle. A chain of length 2 is simply a head
		# to head so we ignore those.
		if order? and !order.succeeds
			# debug 'Breaking cycle...'
			return 'SUCCEEDS'

	handleCycle = ({cycle}, order) ->

		# debug 'FIRST'
		first = cycle.replay 'SUCCEEDS'

		# debug 'SECOND'
		second = cycle.replay 'FAILS'

		# Same result so it doesn't matter which decision we use.
		if first is second
			# debug 'CONSISTENT OUTCOME'
			cycle.remember(first)
			return first
		else
			breakCircularMovement(order) or
			throw new Error 'Unhandleable cycle detected.'

	self.adjudicate = CycleGuard(self.adjudicate, handleCycle).fork()

	return self

module.exports = Resolver
