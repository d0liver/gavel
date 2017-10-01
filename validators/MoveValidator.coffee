parseOrder = require '../parseOrder'

{english, legal, orders: eorders, paths} = require '../enums'
{MOVE, SUPPORT, CONVOY, HOLD}            = eorders

class MoveValidator
	constructor: (@_board, @_pfinder) ->

	isLegal: (order, country = null) ->
		order = parseOrder order

		# Order was given for the wrong country
		country? and order.country is country? and (
			# Check if there is a valid path for any MOVE using any of the
			# units on the board
			order.type isnt MOVE or
			!@_pfinder.hasPath(order, @_board.units(), order.via_convoy)?
		)

module.exports = MoveValidator
