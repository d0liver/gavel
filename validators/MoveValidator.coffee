parseOrder = require '../parseOrder'

{english, legal, orders: eorders, paths} = require '../enums'
{MOVE, SUPPORT, CONVOY, HOLD}            = eorders

class MoveValidator
	constructor: (@_board, @_pfinder) ->

	isLegal: (order, country = null) ->
		order = parseOrder order

		# Check order was given for the wrong country
		country? and order.country is country and (
			# Check if there is a valid path for any MOVE using any of the
			# units on the board
			order.type is MOVE and
			!!@_pfinder.hasPath(order, @_board.units(), order.via_convoy)?
			# order.type is SUPPORT and
			# @_board.canSupport order or
			# order.type is CONVOY and
			# @_board.canConvoy order
		)

module.exports = MoveValidator
