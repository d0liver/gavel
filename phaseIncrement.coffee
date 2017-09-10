exports.adjustPhase = (phase, adjustment) ->
	seasons = ['Spring', 'Spring Retreat', 'Fall', 'Fall Retreat', 'Winter']
	[season, year] = exports.parsePhase phase

	year = Math.floor (year*seasons.length + seasons.indexOf(season) + adjustment)/seasons.length

	season = seasons[(seasons.indexOf(season) + adjustment) %% seasons.length]

	return "#{season} #{year}"

exports.parsePhase = (phase) ->
	pieces = phase.split /\s+/
	season = pieces[0...-1].join ' '
	year = +pieces[-1..-1]

	return [season, year]

exports.incPhase = (phase) -> exports.adjustPhase phase, 1

exports.decPhase = (phase) ->
	new_phase = exports.adjustPhase phase, -1

	# Cap the starting phase at 1901
	if exports.parsePhase(new_phase)[1] < 1901
		return phase
	else
		return new_phase
