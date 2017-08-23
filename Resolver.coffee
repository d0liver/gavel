# 3rd Party,
_ = require 'underscore'

# Local
CycleGuard       = require './CycleGuard'
{CycleException} = require './Exceptions'
describeOrder    = require './describeOrder'
{english, outcomes, orders: eorders, paths} = require './enums'

{VIA_ADJACENCY, VIA_CONVOY}                = paths
{MOVE, SUPPORT, CONVOY, HOLD}      = eorders
{SUCCEEDS, FAILS, ILLEGAL, EXISTS} = outcomes

# TODO: Test valid units check
# TODO: Add coasts to self.apply unit results
# Adapted from "The Math of Adjudication" by Lucas Kruijswijk
# We assume in the resolver that the map constraints have been satisfied (moves
# are to valid locations, etc.)
# pfinder = PathFinder instance
Resolver = (board, pfinder, orders, options) ->
	depth = -1
	self = {}
	{TEST = false, DEBUG = false} = options

	self.resolve = (order) ->
		try
			order.succeeds = self.adjudicate order
		catch err
			if err instanceof CycleException
				order.succeeds = handleCycle err, order
			else
				throw err

		return order.succeeds

	succ = (result) -> (result and SUCCEEDS) or (!result and FAILS)

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
		# region. We probably need to consider getting rid of the ILLEGAL
		# result and just returning fails because ILLEGAL can get really
		# complicated.

		unless valid_region and not hop_move
			return ILLEGAL

		debug "Resolving #{describeOrder order}"

		switch order.type
			when MOVE
				# Preflight checks. Coast must be specified if the region has
				# coasts. We must have a path to the destination.
				unless hasPath(order)?
					debug "No path exists for this order"
					return FAILS
				else
					debug "Path: #{english paths, hasPath order}"

				debug "Checking for preventers..."
				# Get the largest prevent strength
				preventers = (ordersWhere(order, MOVE, EXISTS, to: order.to) ? [])
				.filter (o) -> hasPath(o)?

				debug "TO: #{order.to}"
				debug "Number of preventers: #{preventers.length}"

				prevent_strength = preventers.reduce (max, preventer) ->
					Math.max max, preventStrength preventer
				, 0
				debug "Prevent strength is: #{prevent_strength}"

				attack_strength = attackStrength(order)
				debug "Attack strength is: #{attack_strength}"

				[opposing_order] = ordersWhere(order, MOVE, EXISTS,
					to: order.from
					from: order.to
				) ? []

				head_to_head = opposing_order? and (
					hasPath(order) is VIA_ADJACENCY and
					hasPath(opposing_order) is VIA_ADJACENCY
				)

				hold_strength = holdStrength(order.to)
				debug "Hold strength is: #{hold_strength}"

				if head_to_head
					defend_strength = defendStrength opposing_order
					debug "#{opposing_order.country}'s #{opposing_order.utype} defends with a strength of #{defend_strength}"

				debug "Is head to head? #{head_to_head}"

				succeeds = succ attack_strength > prevent_strength and (
						(
							head_to_head and attack_strength > defend_strength
						# NOT a head to head battle
						) or not head_to_head and attack_strength > hold_strength
					)

				debug "#{order.country}'s #{order.utype} #{english outcomes, succeeds}"
				return succeeds

			when SUPPORT
				# Support can only be into an adjacent region
				unless (
					(
						# TODO: Consider revising this hold stuff. If an army
						# moves away it shouldn't be illegal because that army
						# could be an enemy army. It should still fail though.
						order.to is 'Hold' and
						! ordersWhere null, MOVE, EXISTS, from: order.from
					) or
					board.canSupport order
				) and order.actor isnt order.from
					return ILLEGAL

				debug "Checking if support order was cut..."
				[cut] = ordersWhere(
					order, MOVE, EXISTS,
					to: order.actor
					from: (f) ->
						f isnt order.to
					country: (c) -> c isnt order.country
				) ? []

				# A support cut isn't valid if the path fails
				cut = cut? and hasPath(cut)?

				# We have to do dislodgement as a separate case because it's
				# possible to have a situation where you can't naively cut
				# support because the other unit is a unit supporting against
				# your own region but you can actually dislodge the offending
				# unit in which case the support is actually cut. See test case
				# 6.D.17 for an example.
				dislodged = ordersWhere order, MOVE, SUCCEEDS, to: order.actor

				# If there is a move order moving to the unit that is supporting
				# that is not the destination of the support (you can't cut a
				# support that's supporting directly against you) then the support
				# will be cut (even when the move order failed)
				return succ !dislodged and !cut

			when CONVOY, HOLD
				debug "CONVOY or HOLD is dislodged?"
				# A convoy succeeds when it's not dislodged. We know that we can't
				# move and convoy at the same time so it's sufficient to check if
				# there was a successful move to the convoyer.
				return succ ! ordersWhere null, MOVE, SUCCEEDS, to: order.actor

	hasPath = (order)->
		{country, utype, from, to, from_coast, to_coast, via_convoy} = order
		has_convoy_intent =
			!! ordersWhere null, CONVOY, EXISTS, {from, to, country: (c) -> c is country}

		debug "Via convoy? #{via_convoy}"
		debug "Convoy intent? #{has_convoy_intent}"

		# We have a _from_ connected directly to the _to_. This is the normal
		# case where convoys don't come into play.
		if !via_convoy and !has_convoy_intent and
		board.canMove {utype, from, to, from_coast, to_coast}
			return VIA_ADJACENCY
		# Convoys are valid when it's an army being convoyed and the
		# destination is on land.
		else if utype is 'Army' and board.region(to).type is 'Land'
			corders = ordersWhere(null, CONVOY, SUCCEEDS, {from, to}) ? []
			# convoyPath expects which units, rather than which orders should
			# be considered for the convoy path.
			units = (board.region(corder.actor).unit for corder in corders)
			return VIA_CONVOY if pfinder.convoyPath({from, to}, units).length isnt 0

	holdStrength = (region) ->
		debug 'Calculating hold strength...'
		region_has_units = !! orders.find (o) -> o.actor is region
		# If the region started empty or contains a unit that moved
		# successfully then hold strength is 0
		if !region_has_units or ordersWhere(null, MOVE, SUCCEEDS, from: region)
			return 0
		# If a unit tried to move from this region and failed then hold strength is
		# 1.
		else if !! ordersWhere(null, MOVE, FAILS, from: region)
			return 1
		else
			supports = ordersWhere null, SUPPORT, SUCCEEDS, from: region, to: 'Hold'

			return 1 + (supports?.length ? 0)

	attackStrength = (order) ->
		debug 'Calculating attack strength...'
		oW = ordersWhere.bind null, order
		# TODO: This needs review
		dest_order = !! oW MOVE, SUCCEEDS, from: order.to
		occupier = orders.find (o) -> o.actor is order.to

		# This is NOT a head to head battle. The destination is empty and
		# therefore we can support against it even if it was our unit that
		# moved away (because it is now empty). However, if our unit did not
		# move away successfully then we cannot dislodge it so we fall through
		# to the second or third situation (depending upon if the unit moving
		# to the destination is the same nationality as the destination unit)
		if !occupier? or (
			dest_order and
			(dest_order.to isnt order.from or hasPath destOrder is VIA_CONVOY)
		)
			return 1 + support order
		else if occupier?.country is order.country
			# We can't dislodge our own units
			return 0
		else
			# Head to head battle. The attack strength is now 1 plus the number of
			# supporting units (but units can't support against their own).
			{from, to} = order
			val = 1 + (oW(
				SUPPORT, SUCCEEDS, {
					from, to,
					country: (c) -> c isnt occupier?.country
				}
			)?.length ? 0)
			return val

	defendStrength = (order) ->
		debug 'Calculating defend strength...'
		return 1 + support(order)

	preventStrength = (order) ->
		debug 'Calculating prevent strength...'
		# TODO: We may want to consolidate all of the head to head checks
		[opposing_order] =
			ordersWhere(order, MOVE, SUCCEEDS, to: order.from, from: order.to) ? []
		if opposing_order?
			debug "Opposing order: #{describeOrder opposing_order}"
			debug "Opposing order path: #{english paths, hasPath opposing_order}"
		# For a head to head battle where the other side was successful our
		# strength is 0
		if opposing_order? and
		hasPath(opposing_order) isnt VIA_CONVOY and
		hasPath(order) isnt VIA_CONVOY
			return 0
		else
			return 1 + support(order)

	# Get the number of supports for an order
	support = (order) ->
		{from, to} = order
		return ordersWhere(order, SUPPORT, SUCCEEDS, {from, to})?.length ? 0

	ordersWhere = (current, type, requires, matches = {}) ->
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
			if result isnt ILLEGAL and
			(requires is EXISTS or result is requires)
				results.push order

		# This makes it so that we can use the results as a boolean or use the
		# actual results which is convenient.
		return results if results?.length

	self.describeMatches = (matches) ->
		result = ""
		for key, val of matches when typeof val isnt 'function'
			result += "#{key} #{val} "

		return result

	# Go through the resolved orders and apply the changes to the board
	# (including contests, etc.). This has been done in a separate function
	# rather than in adjudicate because I'm still not sure how I feel about
	# this. The rest of the resolver is pure and doesn't have side effects so
	# I'm not sure that I want to go littering everything with the added
	# complexity of extra side effects. Calling apply explicitly feels better
	# for now.
	self.apply = ->
		# FIXME: When we do things with ordersWhere it is producing cycle
		# exceptions (which are not handled by us) so we don't use ordersWhere.
		# However, by the time apply is called all orders should have been
		# resolved and so further calls to adjudicate should only produced
		# canned responses but this isn't the case.
		morders = orders.filter (o) -> o.type is MOVE and o.succeeds is SUCCEEDS
		# Set dislodged units. We're careful not to set 
		for dislodger in morders
			board.setDislodger
				# If the dislodger came over sea then it's okay actually to
				# retreat to their region but the unit is still dislodged so we
				# just let the dislodger be undefined in that case (test case
				# 6.H.11)
				dislodger:
					if hasPath(dislodger) is VIA_ADJACENCY then dislodger.actor
					else true
				region: dislodger.to

		# Set contested regions
		morders = orders.filter (o) -> o.type is MOVE
		for order in morders
			# If we just check the preventStrength on each order it won't work
			# because it will assume that we are actually preventing something
			# (preventStrength gets the strength of a preventer). Thus, we have
			# to first determine the preventers on our own and then decide if
			# the region is contested. I.e. if a move only comes from one side
			# (no contest) you will get a preventStrength for that move if you
			# check because it assumes some other move is being prevented by
			# that one.
			preventers = orders.filter (o) ->
				o.type is MOVE and
				o.to is order.to and
				hasPath(o)?

			prevent_strength = preventers.reduce (max, preventer) ->
				Math.max max, preventStrength preventer
			, 0
			if prevent_strength > 0
				board.setContested order.to

		# Go ahead and move the units where orders succeeded
		morders = orders.filter (o) -> o.type is MOVE and o.succeeds is SUCCEEDS
		for order in morders
			# TODO: This actually should happen in the RetreatResolver
			board.removeUnit order.to
			board.removeUnit order.from
			board.addUnit order.country, {type: order.utype, region: order.to}

	breakCircularMovement = (dependencies) ->
		# The first order will be the one that started the cycle.
		order = dependencies[0]

		# Obviously circular movements can only occur when the order itself is
		# a move
		return false if order.type isnt MOVE

		# List of moves that have been seen so far in this chain
		chain = []
		morders = _.where orders, type: MOVE

		while order? and order.from not in chain and !order.succeeds?
			chain.push order.from
			order = morders.find (o) -> order.from is o.to

		# If order was defined then that means that we broke out of the
		# loop because a cycle was detected (otherwise we would hit the end
		# of the chain). In that case, we want to resolve our order with a
		# success to break the cycle. A chain of length 2 is simply a head
		# to head so we ignore those.
		if order? and !order.succeeds
			order.succeeds = SUCCEEDS

	# Szykman rule for resolving convoy paradoxes. The rule says that if a
	# paradox results from a convoy then we treat the convoy as disrupted.
	convoyParadox = (dependencies) ->
		for order in dependencies when order.type is CONVOY
			order.succeeds = FAILS

	handleCycle = ({cycle, dependencies}, order) ->

		# Reset the depth counter since we broke out of the stack.
		depth = 0

		debug 'CYCLE OCCURRED -- Attempting to find a consistent resolution.'
		debug 'CYCLE OCCURRED -- First, replay with a guess of SUCCEEDS'
		first = cycle.replay SUCCEEDS

		debug 'CYCLE OCCURRED -- Now, replay with a guess of FAILS'
		second = cycle.replay FAILS

		# Same result so it doesn't matter which decision we use.
		if first is second
			debug 'CYCLE OCCURRED -- Consistent outcome'
			cycle.remember first
		else
			# NOTE: DO NOT USE _order_ for the dependency name here. That name
			# is already taken and it will mess things up in a way that's
			# difficult to find.
			dependencies = (dep for [dep] in dependencies)
			debug 'CYCLE OCCURRED -- Attempting to break circular movement'
			breakCircularMovement(dependencies) or
			convoyParadox(dependencies) or
			throw new Error 'Unhandleable cycle detected.'

		return self.resolve order

	self.adjudicate = CycleGuard(self.adjudicate, handleCycle).fork()

	debug = (message) ->
		if DEBUG ? false
			tabs = ('\t' for i in [0...depth]).join ''
			console.log "#{tabs} #{message}"

	# Increment depth before function call, decrement after.
	depthWrapper = (fu) -> (args...) -> ++depth; result = fu args...; --depth; result

	# Wrap some of the functions with a wrapper that counts the current depth
	# level so that we can show debug outputs nicely
	self.adjudicate = depthWrapper self.adjudicate
	ordersWhere     = depthWrapper ordersWhere
	holdStrength    = depthWrapper holdStrength
	attackStrength  = depthWrapper attackStrength
	preventStrength = depthWrapper preventStrength
	defendStrength  = depthWrapper defendStrength

	return self

module.exports = Resolver
