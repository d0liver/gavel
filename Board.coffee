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
		region = utils.copy regions[rname]
		region.unit = _.findWhere units(), region: rname
		return region

	self.adjacentRegions (rname) ->

	fleets = -> yield from units.bind null, 'Fleet'
	armies = -> yield from units.bind null, 'Army'

	areAdjacent = (from, to) ->
		regions = gdata.map_data.regions

		region = do ->
			return region for rname,region of regions when rname is from

		return to in _.pluck(region.adjacencies, 'region')

	units = (type) ->
		_.filter _.union(_.pluck(countries, 'units')...),
			-> not type? or unit.type is type

	return self

module.exports = Board
