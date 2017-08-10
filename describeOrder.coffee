{
	english
	orders: {MOVE, SUPPORT, CONVOY, HOLD}
	outcomes
} = require './enums'

describeOrder = (order) ->

	region = (order) -> board.region order.actor
	dscr = switch order.type
		when CONVOY then "
			#{order.country}'s Fleet in
			#{order.actor} convoys #{order.from} to #{order.to}
		"
		when SUPPORT then "
			#{order.country}'s
			#{order.utype} in #{order.actor} supports
			#{order.utype} in #{order.from} to #{order.to}
		"
		when MOVE then "
			#{order.country}'s
			#{order.utype} in #{order.from} moves to #{order.to}
		"
	return dscr + "#{pad english(outcomes, order.succeeds), ' '}"

pad = (str, end = '') -> str and "#{end or ' '}#{str}#{end}" or '' 

module.exports = describeOrder
