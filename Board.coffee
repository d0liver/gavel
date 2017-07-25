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

	self.adjacencies = (from, to) ->
		regions = gdata.map_data.regions

		region = do ->
			return region for rname,region of regions when rname is from

		return _.pluck region.adjacencies.filter((a) -> a.region is to), 'type'

	units = (type) ->
		_.union (
			for country in gdata.countries
				for unit in country.units when not type? or unit.type is type
					_.extend {}, unit, {country}
		)...

	return self

module.exports = Board
