exports.describeSucceeds = (succeeds) ->
	return (
		if typeof succeeds is 'boolean' and succeeds
			'SUCCEEDS'
		else if typeof succeeds is 'boolean' and not succeeds
			'FAILS'
		else if not succeeds?
			'UNRESOLVED'
	)

exports.describe = (order) ->

	dscr = switch order.type
		when 'CONVOY' then "
			#{units[order.convoyer].country}'s Fleet in
			#{order.convoyer} convoys #{order.from} to #{order.to}
		"
		when 'SUPPORT' then "
			#{units[order.supporter].country}'s
			#{units[order.supporter].type} in #{order.supporter} supports
			#{units[order.from].type} in #{order.from} to #{order.to}
		"
		when 'MOVE' then "
			#{units[order.from].country}'s
			#{units[order.from].type} in #{order.from} moves to #{order.to}
		"
	return dscr + "#{pad(self.describeSucceeds(order.succeeds), ' ')}"

pad = (str, end = '') -> str and "#{end or ' '}#{str}#{end}" or '' 
