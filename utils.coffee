debug = require './debug'

# Fast way to get orders with certain constraints. When we call this function
# it's almost always to find __other__ orders that will affect the order
# currently being adjudicated. As such, we almost never want to consider the
# _current_ order in our results so we take it as the first argument which
# makes the function signature slightly more confusing but is much more
# convenient.
exports.ordersWhere = (current, type, requires, matches) ->
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

oW = exports.ordersWhere.bind(null, null)

exports.actor = (order) ->
	switch order.type
		when 'MOVE' then order.from
		when 'CONVOY' then order.convoyer
		when 'SUPPORT' then order.supporter

exports.expandUnits = ->
	# It's convenient to have country and region on the units but kind of a pain to
	# keep it updated in both places so we build it out just the once here.
	for region,unit of units
		unit.region = region

		for order in orders
			# Figure out which region is the actor in the order so that we can use
			# that as the key when setting the unit's country.
			region = exports.actor order

			units[region].country = order.country
