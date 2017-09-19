{readOnly} = require './utils'

class Phase

	constructor: (@_phase = "Spring 1901") ->
		[@_season, @_year] = @parse()

		Object.defineProperties @,
			season:
				get: -> @_season
				set: ->
			year:
				get: -> @_year
				set: ->

	adjust: (adjustment) ->
		seasons = ['Spring', 'Spring Retreat', 'Fall', 'Fall Retreat', 'Winter']
		[season, year] = @parse()

		year = Math.floor (year*seasons.length + seasons.indexOf(season) + adjustment)/seasons.length

		season = seasons[(seasons.indexOf(season) + adjustment) %% seasons.length]

		# Cap the starting phase at 1901
		if year > 1900
			@_phase = "#{season} #{year}"
			@_season = season; @_year = year

	parse: ->
		pieces = @_phase.split /\s+/
		season = pieces[0...-1].join ' '
		year = +pieces[-1..-1]

		return [season, year]

	inc: -> @adjust 1; dec: -> @adjust -1

	toString: -> @_phase

module.exports = Phase
