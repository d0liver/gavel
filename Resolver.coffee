CycleGuard = require './CycleGuard'
CycleException = require './CycleException'

# Adapted from "The Math of Adjudication" by Lucas Kruijswijk
# We assume in the resolver that the map constraints have been satisfied (moves
# are to valid locations, etc.)
Resolver = (orders, units, DEBUG = false) ->
	self = {}

	init = ->
		expandUnits()

	showResult = (status) ->
		if DEBUG
			console.log("ORDER #{status}")

	expandUnits = ->
		# It's convenient to have country and region on the units but kind of a pain to
		# keep it updated in both places so we build it out just the once here.
		for region,unit of units
			unit.region = region

			for order in orders
				# Figure out which region is the actor int the order so that we can use
				# that as the key when setting the unit's country.
				region = switch order.type
					when 'MOVE' then order.from
					when 'CONVOY' then order.convoyer
					when 'SUPPORT' then order.supporter

				units[region].country = order.country
	console.log()

	self.resolve = ->
		for order in orders when not order.succeeds?
			try
				order.succeeds = self.adjudicate(order)
			catch err
				if err instanceof CycleException
					order.succeeds = handleCycle err
				else
					throw err

	# nr - The number of the order to be resolved.
	# Returns the resolution for that order.
	self.adjudicate = (order) ->
		console.log "EVALUATING ORDER: ", self.describe(order)

		switch order.type
			when 'MOVE'
				# Get the largest prevent strength
				preventers = ordersWhere(order, 'MOVE', 'EXISTS', to: order.to) or []

				prevent_strength = preventers.reduce (max, preventer) ->
					Math.max max, preventStrength preventer
				, 0

				attack_strength = attackStrength(order)
				[opposing_order] = ordersWhere(order, 'MOVE', 'EXISTS',
					to: order.from
					from: order.to
				) ? []

				hold_strength = holdStrength(order.to)

				if DEBUG
					console.log "OPPOSING ORDER: ", opposing_order
					console.log "ATTACK: ", attack_strength
					console.log "PREVENT: ", prevent_strength
					console.log "HOLD: ", hold_strength
					if opposing_order
						console.log "DEFEND: ", defendStrength(opposing_order)

				return attack_strength > prevent_strength and (
					(
						opposing_order? and
						attack_strength > defendStrength(opposing_order)
					) or
					attack_strength > hold_strength
				)

			when 'SUPPORT'
				# If there is a move order moving to the unit that is supporting
				# that is not the destination of the support (you can't cut a
				# support that's supporting directly against you) then the support
				# will be cut (even when the move order failed)
				if order.supporter is 'Greece'
						to: order.supporter
						from: (f) -> f isnt order.to
						country: (c) -> c isnt order.country
				return ! ordersWhere order, 'MOVE', 'EXISTS',
					to: order.supporter
					from: (f) ->
						f isnt order.to
					country: (c) -> c isnt order.country

			when 'CONVOY'
				# A convoy succeeds when it's not dislodged. We know that we can't
				# move and convoy at the same time so it's sufficient to check if
				# there was a successful move to the convoyer.
				return ! ordersWhere order, 'MOVE', 'SUCCEEDS', to: order.convoyer

	holdStrength = (region) ->
		oW = ordersWhere.bind(null, null)
		# If the region is empty or contains a unit that moved successfully then
		# hold strength is 0
		if not units[region]? or oW('MOVE', 'SUCCEEDS', from: region)
			return 0
		# If a unit tried to move from this region and failed then hold strength is
		# 1.
		else if !! oW('MOVE', 'FAILS', from: region)
			return 1
		else
			# TODO: A unit cannot support itself to hold. Make sure this is
			# addressed in the map constraints.
			return 1 + (oW('SUPPORT', 'SUCCEEDS', from: region, to: region)?.length ? 0)

	attackStrength = (order) ->
		oW = ordersWhere.bind(null, order)
		# TODO: Check and see if the path for this attack was successful (deal with
		# convoys, ugh)
		# TODO: This needs review
		res = oW('MOVE', 'SUCCEEDS', {from: order.to})
		dest_order =
			if res?.length is 1
				res[0]
			else
				undefined

		if (not units[order.to]?) or (dest_order? and dest_order.to isnt order.from)
			return 1 + support(order)
		else if units[order.to]?.country is order.country
			# We can't dislodge our own units
			return 0
		else
			# Head to head battle. The attack strength is now 1 plus the number of
			# supporting units (but units can't support against their own).
			{from, to} = order
			val = 1 + (oW(
				'SUPPORT', 'SUCCEEDS', {from, to},
				country: (c) ->
					c isnt units[order.to]?.country
			)?.length ? 0)
			return val

	defendStrength = (order) ->
		return 1 + support(order)

	preventStrength = (order) ->
		# TODO: Check and see if the path was successful.
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

	# Fast way to get orders with certain constraints. When we call this function
	# it's almost always to find __other__ orders that will affect the order
	# currently being adjudicated. As such, we almost never want to consider the
	# _current_ order in our results so we take it as the first argument which
	# makes the function signature slightly more confusing but is much more
	# convenient.
	ordersWhere = (current, type, requires, matches) ->
		results = []
		`outer: //`
		for order in orders when order.type is type and order isnt current
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
			if requires is 'EXISTS' or
			(self.adjudicate(order) and requires is 'SUCCEEDS') or
			(!self.adjudicate(order) and requires is 'FAILS')
				results.push order

		# This makes it so that we can use the results as a boolean or use the
		# actual results which is convenient.
		return results if results?.length


	self.describeSucceeds = (succeeds) ->
		return (
			if typeof succeeds is 'boolean' and succeeds
				'SUCCEEDS'
			else if typeof succeeds is 'boolean' and not succeeds
				'FAILS'
			else if not succeeds?
				'UNRESOLVED'
		)

	self.describe = (order) ->

		dscr = switch order.type
			when 'CONVOY' then "
				#{units[order.convoyer].country}'s Fleet in
				#{order.convoyer} convoys #{order.from} to #{order.to}
			"
			when 'SUPPORT' then "
				#{units[order.supporter].country}'s
				#{units[order.supporter].type} in #{order.supporter} supports
				#{units[order.from].type} in #{order.from} to #{order.to}
			"
			when 'MOVE' then "
				#{units[order.from].country}'s
				#{units[order.from].type} in #{order.from} moves to #{order.to}
			"
		return dscr + "#{pad(self.describeSucceeds(order.succeeds), ' ')}"

	pad = (str, end = '') -> str and "#{end or ' '}#{str}#{end}" or '' 

	handleCycle = ({cycle}) ->

		console.log "FIRST"
		first = cycle.replay(true)

		console.log "SECOND"
		second = cycle.replay (false)

		# Same result so it doesn't matter which decision we use.
		if first is second
			console.log "CONSISTENT OUTCOME"
			cycle.remember(first)
			return first
		else
			# We achieved different outcomes so there is some symmetric cycle
			# at work and we need a fallback rule to adjudicate.
			return cycle.replay(fallback(cycle))

	fallback = (cycle) ->
		throw new Error "Fallback not implemented"

	self.adjudicate = CycleGuard(self.adjudicate, handleCycle).fork()

	init()
	return self

basic_test_cases =
	move_depends:
		orders: [
			type: 'MOVE'
			from: 'A'
			to: 'B'
			country: 'BigBird'
		,
			type: 'MOVE'
			from: 'B'
			to: 'C'
			country: 'Boss'
		,
			type: 'MOVE'
			from: 'C'
			to: 'D'
			country: 'Boss'
		]
		units:
			A: type: 'Army'
			B: type: 'Army'
			C: type: 'Army'
		expects: [true, true, true]

	support:
		orders: [
			type: 'MOVE'
			from: 'A'
			to: 'C'
			country: 'BigBird'
		,
			type: 'MOVE'
			from: 'B'
			to: 'C'
			country: 'Boss'
		,
			type: 'SUPPORT'
			supporter: 'D'
			from: 'B'
			to: 'C'
			country: 'Boss'
		]
		units:
			A: type: 'Army'
			B: type: 'Army'
			D: type: 'Army'
		expects: [false, true, true]
	cyclic_move:
		orders: [
			type: 'MOVE'
			from: 'A'
			to: 'B'
			country: 'BigBird'
		,
			type: 'MOVE'
			from: 'B'
			to: 'C'
			country: 'Boss'
		,
			type: 'MOVE'
			from: 'C'
			to: 'A'
			country: 'Boss'
		,
			type: 'SUPPORT'
			country: 'BigBird'
			from: 'A'
			to: 'B'
			supporter: 'D'
		]
		units:
			A: type: 'Army'
			B: type: 'Army'
			C: type: 'Army'
			D: type: 'Army'
		expects: [true, true, true, true]
	convoy_paradox:
		orders: [
				type: 'SUPPORT'
				from: 'Aegean'
				to: 'Ionian'
				supporter: 'Greece'
				country: 'Turkey'
			,
				type: 'SUPPORT'
				from: 'Aegean'
				to: 'Ionian'
				supporter: 'Albania'
				country: 'Austria'
			,
				type: 'MOVE'
				from: 'Aegean'
				to: 'Ionian'
				country: 'Turkey'
			,
				type: 'CONVOY'
				convoyer: 'Ionian'
				from: 'Tunis'
				to: 'Greece'
				country: 'Italy'
			,
				type: 'MOVE'
				from: 'Tunis'
				to: 'Greece'
				country: 'Italy'
		]
		units:
			Greece: type: 'Fleet'
			Albania: type: 'Fleet'
			Aegean: type: 'Fleet'
			Ionian: type: 'Fleet'
			Tunis: type: 'Army'
		expects: [true, true, true, false, false]


# Show all orders first
testCases = ->
	# Prevent a bunch of extra noise when running the tests.

	for title,{orders, units, expects} of basic_test_cases
		console.log "\nRunning test: ", title
		resolver = Resolver(orders, units, true)

		console.log(resolver.describe(order)) for order in orders
		console.log()

		resolver.resolve(order)

		console.log(resolver.describe(order)) for order in orders

		for order,i in orders when order.succeeds isnt expects[i]
			console.log "Test failed: ", title
			return

	console.log "All tests passed successfully."

testCases()

module.exports = Resolver
