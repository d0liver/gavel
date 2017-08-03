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

	# Returns the adjacencies available from _from_ to _to_. In the case that a
	# coast is specified we return the adjacencies for the given coast instead.
	self.adjacencies = (from, to) ->
		regions = gdata.map_data.regions

		region = do ->
			return region for rname,region of regions when rname is from

		adjacencies =
			if from_coast? then region.coasts[coast].adjacencies
			else region.adjacencies

		for adj in adjacencies when adj.region is to
			# TODO: The logic below is a kind of hack that converts an
			# adjacency that is from a region to a coast into one that
			# follows the nc, sc, ec, wc convention. It's necessary because
			# of the way that the parser works currently which should be
			# changed.  Putting it here ensures that the Resolver won't
			# need to change when the parser is updated since it will be
			# the same from the point of view of the Resolver.
			unless adj.coast?
				adj.type
			else switch adj.coast
				when 'North' then 'nc'
				when 'South' then 'sc'
				when 'East' then 'ec'
				when 'West' then 'wc'

	units = (type) ->
		_.union (
			for country in gdata.countries
				for unit in country.units when not type? or unit.type is type
					_.extend {}, unit, {country}
		)...

	return self

module.exports = Board
