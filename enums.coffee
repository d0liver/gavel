exports.outcomes =
	FAILS    : 0
	SUCCEEDS : 1
	EXISTS   : 2

exports.orders =
	MOVE    : 0
	SUPPORT : 1
	CONVOY  : 2
	HOLD    : 3
	BUILD   : 4

exports.paths =
	VIA_ADJACENCY : 0
	VIA_CONVOY    : 1

exports.english = (which, val)->
	(key for key,value of which when value is val)[0]
