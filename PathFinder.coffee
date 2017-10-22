{paths: {VIA_ADJACENCY, VIA_CONVOY}} = require './enums'

# This isn't part of the board because I don't want reusers to have to
# reimplement this and the board is supposed to be a pluggable representation
# of the board. It's not part of the resolver either because it's often used
# outside of the context of orders resolution (e.g. determining distance for
# disbanding, legality of a potential move order, etc.)
class PathFinder

	constructor: (@_board) ->

	# Return an array of arrays where each subarray is the units for a complete
	# path.
	#
	# __units__ = Units we're considering using for the convoy path. __units__
	# could be all units on the board (for determining move legality), units
	# with successful convoy orders (during orders resolution), etc.
	convoyPath: ({from, to}, units, path = []) ->

		# We found a complete path, remember it.
		if @_board.canConvoy(convoyer: from, convoyee: to)
			return path

		# We don't have a complete path yet, so we have to keep looking for
		# convoys that can get us there.
		next_hops = (
			unit for unit in units ? [] when \
			# Don't chase our own tail.
			! path.find((u) -> unit.region is u.region) and
			@_board.canConvoy convoyee: from, convoyer: unit.region
		)

		# Find all of our possible paths and assign them each a subarray. Make
		# sure to filter out failed paths which come back as empty paths.
		(for hop in next_hops
			path = [path..., hop]
			@convoyPath {from: hop.region, to}, units, path
		).filter (p) -> p.length isnt 0

	# Check if a path exists for an order using the given units. If via_convoy
	# is specified then moves must be performed via an available convoy and
	# fail if none exists. TODO: Could be named better - this doesn't actually
	# return a boolean but rather a path type.
	hasPath: (order, units, via_convoy = false) ->

		# We have a _from_ connected directly to the _to_. This is the normal
		# case where convoys don't come into play.
		if !via_convoy and @_board.canMove order
			return VIA_ADJACENCY
		# Convoys are valid when it's an army being convoyed and the
		# destination is on land.
		else if order.utype is 'Army' and @_board.region(order.to).type is 'Land'
			return VIA_CONVOY if @convoyPath(order, units).length isnt 0

module.exports = PathFinder
