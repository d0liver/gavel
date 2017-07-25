which = ['Resolver', 'DATC']

module.exports = (flag) ->
	(args...) ->
		if flag in which
			# Print debug messages where they're enabled (in _which_)
			console.log "DEBUG: ", args...
