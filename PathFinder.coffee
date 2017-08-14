# This isn't part of the board because I don't want reusers to have to
# reimplement this and the board is supposed to be a pluggable representation
# of the board. It's not part of the resolver either because it's often used
# outside of the context of orders resolution (e.g. determining distance for
# disbanding, legality of a potential move order, etc.)
PathFinder = (board) ->
	self = {}

	# Return an array of arrays where each subarray is the units for a complete
	# path.
	#
	# __units__ = Units we're considering using for the convoy path. __units__
	# could be all units on the board (for determining move legality), units
	# with successful convoy orders (during orders resolution), etc.
	self.convoyPath = ({from, to}, units, path = []) ->

		# We found a complete path, remember it.
		if board.canConvoy(convoyer: from, convoyee: to)
			return path

		# We don't have a complete path yet, so we have to keep looking for
		# convoys that can get us there.
		next_hops = (
			unit for unit in units ? [] when \
			# Don't chase our own tail.
			! path.find((u) -> unit.region is u.region) and
			board.canConvoy convoyee: from, convoyer: unit.region
		)

		# Find all of our possible paths and assign them each a subarray. Make
		# sure to filter out failed paths which come back as empty paths.
		(for hop in next_hops
			path = [path..., hop]
			self.convoyPath {from: hop.region, to}, units, path
		).filter (p) -> p.length isnt 0

	return self

module.exports = PathFinder
