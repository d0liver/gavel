CycleGuard                                = require './CycleGuard'
{CycleException, NotImplementedException} = require './CustomExceptions'
debug                                     = require './debug'

# Adapted from "The Math of Adjudication" by Lucas Kruijswijk
# We assume in the resolver that the map constraints have been satisfied (moves
# are to valid locations, etc.)
Resolver = (orders, units, DEBUG = false) ->
	self = {}

	init = ->
		expandUnits()

	self.resolve = ->
		for order in orders when not order.succeeds?
			try
				order.succeeds = self.adjudicate(order)
			catch err
				if err instanceof CycleException
					order.succeeds = handleCycle err
				else
					throw err

	handleCycle = ({cycle}) ->

		debug 'Guessing cycle outcome is true...'
		first = cycle.replay true

		debug 'Guessing cycle outcome is false...'
		second = cycle.replay false

		# Same result so it doesn't matter which decision we use.
		if first is second
			console.log 'True and false outcomes were consistent.' 
			cycle.remember first
			return first
		else
			# We achieved different outcomes so there is some symmetric cycle
			# at work and we need a fallback rule to adjudicate.
			return cycle.replay fallback cycle

	fallback = (cycle) ->
		throw new NotImplementedException "Fallback not implemented"

	self.adjudicate = CycleGuard(self.adjudicate, handleCycle).fork()

	init()
	return self
