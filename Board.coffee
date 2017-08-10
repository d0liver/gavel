# 3rd Party
_ = require 'underscore'

# Local
utils = require './utils'

# gdata = Game data. Consult the docs for the format (or look at the sample
# data for the test cases)
Board = (gdata) ->
	self = {}; orders = {}

	self.addOrder = (order) -> orders[utils.actor(order)] = order

	# Get the full information for a region. Currently this is just what we get
	# from the game data but with the unit added to it (because units are
	# attached to the country in the incoming data).
	self.region = (rname) ->
		return unless rname of gdata.map_data.regions

		region = utils.copy gdata.map_data.regions[rname]
		region.unit = _.findWhere units(), region: rname
		return region

	fleets = -> yield from units.bind null, 'Fleet'
	armies = -> yield from units.bind null, 'Army'

	self.adjacencies = ({from, from_coast, to, to_coast, utype}) ->
		region = gdata.map_data.regions[from]

		# If no coast is specified then we return all adjacencies (include all
		# coasts).
		unless from_coast?
			adjacencies = region.adjacencies
			for coast_name, coast of region.coasts
				adjacencies.push coast.adjacencies...
		# If the coast was specified then we limit our results to only what's
		# valid from that coast.
		else
			adjacencies = region.coasts[from_coast]

		# We return adjacencies to the destination optionally filtering them by
		# unit type (utype) and a destination coast (to_coast)
		adjacencies =
			for adjacency in adjacencies ? [] when adjacency.region is to and
			(not utype? or utype is adjacency.for) and
			(not to_coast? or to_coast is adjacency.coast)
				adjacency

		return adjacencies if adjacencies.length > 0

	self.hasCoast = (rname) ->
		Object.keys(gdata.map_data.regions[rname].coasts).length isnt 0

	# Coasts don't matter because convoys only deal with open water and armies
	# neither of which deal with coasts.
	self.canConvoy = ({convoyer, convoyee}) ->
		!! self.adjacencies(
			utype: 'Fleet'
			from: convoyee
			to: convoyer
		) and self.region(convoyer).type is 'Water'

	# The destination coast does not matter (e.g. a fleet adjacent to the south
	# coast can support a move to the north coast). However, the from_coast
	# matters because it would be impossible to support into a region that
	# isn't adjacent to your coast.
	self.canSupport = ({utype, actor, to, actor_coast}) ->
		query = {from: actor, utype, to}
		query.from_coast = actor_coast if self.hasCoast actor
		!! self.adjacencies query

	self.canMove = ({utype, from, to, from_coast, to_coast}) ->

		# For armies we don't have to worry about coasts
		if utype is 'Army' and self.adjacencies {utype, from, to}
			return true
		# Fleets are different because we have to specify coasts for from and
		# to if they exist.
		else if utype is 'Fleet'
			query = {utype, from, to}
			# We restrict adjacencies to a coast when the coast is defined in
			# the query. Thus, we fallback to true when a coast is required but
			# one was not defined which ensures that no adjacencies will be
			# returned - this is what will happen when a coast is required but
			# none was specified.
			query.from_coast = from_coast ? true if self.hasCoast from
			query.to_coast = to_coast ? true if self.hasCoast to
			return !! self.adjacencies query

		return false

	# Resolvers use these methods to update the board during resolution.
	self.setContested = (region) ->
		gdata.map_data.regions[region].contested = true

	self.setDislodger = ({region, dislodger}) ->
		gdata.map_data.regions[region].dislodger = dislodger

	self.removeDislodger =  (region) ->
		delete gdata.map_data.regions[region].dislodger

	# Remove a dislodged unit in a region.
	self.removeUnit = (region) ->
		for country in gdata.countries
			for unit,i in country.units when unit.dislodger?
				country.units.splice i, 1

	self.setUnit = (region) ->

	units = (type) ->
		_.union (
			for country in gdata.countries
				for unit in country.units when not type? or unit.type is type
					_.extend {}, unit, {country}
		)...

	return self

module.exports = Board
