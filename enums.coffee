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

# Easily compare two types where one or the other could be a string and the
# other is the actual enum number. This makes things easier when you don't
# actually want to have to require enums to do a simple check of the type of an
# order.
exports.typeIs = (enm, typ1, typ2) ->
	typ1 = exports.reverse enm.orders[typ1] if typeof typ1 is 'string'
	typ2 = exports.reverse enm.orders[typ2] if typeof typ2 is 'string'
	typ1 is typ2

exports.english = (which, val)->
	(key for key,value of which when value is val)[0]

exports.reverse = (enm) -> r = {}; r[v] = k for own k,v of enm; r
