# 3rd Party
_ = require 'underscore'

# Local
utils = require './utils'

# TODO: Make sure that board is handing out copies or read only references for
# everything.
# gdata = Game data. Consult the docs for the format (or look at the sample
# data for the test cases)
Board = (gdata, vdata) ->
	self = {}; orders = {}

	self.addOrder = (order) -> orders[utils.actor(order)] = order

	# Get the full information for a region. Currently this is just what we get
	# from the game data but with the unit added to it (because units are
	# attached to the country in the incoming data).
	self.region = (rname) ->
		return unless rname of vdata.map_data.regions

		region = utils.copy vdata.map_data.regions[rname]
		region.unit = self.units().find (u) -> u.region is rname and not u.dislodger?
		region.dislodged_unit = self.units().find (u) -> u.region is rname and u.dislodger?
		region.name = rname
		return region

	self.adjacencies = ({from, from_coast, to, to_coast, utype}) ->
		region = vdata.map_data.regions[from]

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

	self.homeCenters = (country) ->
		country = gdata.phase.countries.find (c) -> c.name is country
		utils.copy country.supply_centers

	self.hasCoast = (rname) ->
		Object.keys(vdata.map_data.regions[rname].coasts).length isnt 0

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
		gdata.contested_regions ?= []
		gdata.contested_regions.push region

	self.dislodgedUnits = ->
		unit for unit in self.units() when unit.dislodger?

	self.setDislodger = ({region, dislodger}) ->
		for country in gdata.phase.countries
			for unit in country.units when unit.region is region
				unit.dislodger = dislodger

	self.removeDislodger =  (region) ->
		delete vdata.map_data.regions[region].dislodger

	# Remove a dislodged unit in a region.
	self.removeUnit = (region) ->
		console.log "Attempt to remove unit from region: ", region
		for country in gdata.phase.countries
			console.log "Units: ", country.units
			for unit,i in country.units when unit.region is region
				country.units.splice i, 1
				return

		return

	self.addUnit = (country, unit) ->
		country = gdata.phase.countries.find (c) -> c.name is country
		country.units.push unit

	self.clearUnits = ->
		country.units = [] for country in gdata.phase.countries

	self.units = (type) ->
		_.union (
			for country in gdata.phase.countries
				for unit in country.units when not type? or unit.type is type
					_.extend {}, unit, {country}
		)...

	self.adjustments = (country, num) ->
		# XXX: Not using self.country because it will make a copy and we need
		# to make a change. Board data is generally not being handled all that
		# well and this should probably be fixed.
		country = gdata.phase.countries.find (c) -> c.name is country
		country.adjustments = num if num?

		return country.adjustments ? 0

	self.adjust = (country, byy) ->
		adjustments = self.adjustments country
		self.adjustments country, adjustments + byy
		return

	self.country = (country) ->
		utils.copy gdata.phase.countries.find (c) -> c.name is country

	self.countries = -> utils.copy gdata.phase.countries
	self.regions = ->
		for name,region of vdata.map_data.regions
			yield self.region(name)

	self.supplyCenters = (country) ->
		if country
			country = gdata.phase.countries.find (c) -> c.name is country
			return country.supply_centers?.length ? 0
		else
			regions = vdata.map_data.regions
			name for name,region of regions when region.supply_center

	# Return the country owning the region if it is an owned supply center
	self.countryOwns = (rname) ->
		gdata.phase.countries.find (c) -> rname in c.supply_centers

	self.moveUnit = (unit, to) ->
		# FIXME: The weird remove then add crap is because the unit that is
		# passed in is a copy of the real unit. Really units should have their
		# own interface so we can just say unit.move(region) and have it guard
		# its own internal state.
		self.removeUnit unit.region
		unit.region = to
		self.addUnit unit.country.name, type: unit.type, region: unit.region

	return self

module.exports = Board
