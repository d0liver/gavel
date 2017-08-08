{CycleException} = require './Exceptions'

# TODO: Split out the memoizer (or just use someone else's)
CycleGuard = (fu, bak, parent) ->
	self = {}
	memo = []
	previous_args = []
	# Stores the repeated argument (that starts and ends the cycle) for easier
	# replay.
	repeat = null
	cbreak = null
	guard = null

	# Detect cyclic recursions (based on the arguments) in fu and call bak when one
	# is detected. We use this to abstract away the cycle detection stuff in the
	# deadpotato resolver which should make things a little easier to read.
	self.fork = ->

		guard = (args...) ->
			# Have we seen these arguments before? If so then we assume there is a
			# cycle happening (we need one cycleGuard per root call to the
			# recursion)
			cycle = !! previous_args.find (pargs) -> arrayEq pargs, args

			# Cycle started and no cbreak was specified so we throw the
			# exception and let the caller set it up.
			if cycle and not cbreak?
				repeat = args
				throw new CycleException self, args
			# We hit the bottom of the cycle again but we have a way to resolve
			# it this time.
			else if cycle and cbreak?
				return cbreak
			# Normal call with memoization
			else
				mem = memo.find ((call) -> arrayEq call.args, args)
				# Check and see if we have memoized these args. The check for
				# mem.result? is in case we started the memoize before but
				# ended up breaking out because a cycle was detected. In that
				# case we need to run it again with a proper result for the
				# cycle which will have been stored by now.
				if mem? and mem.result?
					return mem.result

				try
					# We pop args off of the stack for calls that returned
					# correctly. This way we don't trigger cycle alerts for normal
					# recursion.
					previous_args.push args
					m = result: null, args: args

					# Memoized results aren't popped off so that if we're
					# called multiple times but not in a recursive cycle (which
					# is what prev_args checks for) then we can optimize
					# results. Also, we want the memo to contain the results
					# but we also want the memo array to start with the topmost
					# calls which won't happen unless we push the results
					# BEFORE entering recursion. Therefore, we push now and set
					# the result after.
					memo.push m

					res = fu args...

					m.result = res

					previous_args.pop()
				catch err
					# If there's an error then we need to force clear the
					# 'stack'
					previous_args = []
					throw err

				return res

		return guard

	# Reevaluate from the start of the cycle but this time feed in _cbreak_ as
	# the return value where the cycle would normally occur. In this way we can
	# insert a fake value (e.g. a guess) to break the cyclic call.
	self.break = (cbrk) -> cbreak = cbrk

	# Remove a memoized cycle
	clearCycle = ->
		# When we replay we need to make sure that we get non memoized results
		# so we have to remove the memos for all the calls involved in the
		# cycle.
		memo = memo.slice 0, (memo.findIndex ({args}) -> arrayEq(repeat, args))

	self.replay = (cbrk) ->

		clearCycle()
		self.break cbrk
		res = guard repeat...
		self.break null
		clearCycle()

		return res

	# The user of this module gets to determine how things play out based on
	# the _cbreak_ (cycle break) value that they supplied. Therefore, we let
	# them notify us of their decision so that we can memoize it and prevent
	# future reevaluation of the cycle which is likely expensive.
	self.remember = (val) ->
		memo.push result: val, args: repeat

	arrayEq = (a, b) ->
		return false if not (a? and b?) or a.length isnt b.length
		return false for i in [0...a.length] when a[i] isnt b[i]
		return true

	return self

module.exports = CycleGuard
