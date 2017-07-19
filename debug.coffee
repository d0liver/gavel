DEBUG = true

module.exports =
	if DEBUG
		# Print debug message when DEBUG switch is on
		(args...) -> console.log "DEBUG: ", args...
	else
		-> # Do nothing when DEBUG mode is off
