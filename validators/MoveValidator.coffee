# Checks specific criteria for whether or not a move order is valid.
class MoveValidator
	constructor: (@_engine) ->

	isLegal: (order)->
		console.log "Legal?", @_engine.order(order).hasPath
		@_engine.order(order).hasPath

module.exports = MoveValidator
