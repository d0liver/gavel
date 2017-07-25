parseOrder = (order) ->

	move_re = ///
		^
		([A-Za-z]+)\:           # Country
		\s+(A|F)                # Unit type
		\s+((?:\w+\s+)?(?:\w+)) # Move from
		\s+\-
		\s+((?:\w+\s+)?(?:\w+)) # Move to
		$
	///

	hold_re = ///
		^
		([A-Za-z]+)\:           # Country
		\s+(A|F)                # Unit type
		\s+((?:\w+\s+)?(?:\w+)) # Move from
		\s+Hold
		$
	///

	convoy_re = ///
		^
		([A-Za-z]+)\:           # Country
		\s+F                    # Unit type (fleet)
		\s+((?:\w+\s+)?(?:\w+)) # Convoyer
		\s+Convoys
		\s+A
		\s+((?:\w+\s+)?(?:\w+)) # Move from
		\s+\-
		\s+((?:\w+\s+)?(?:\w+)) # Move to
		$
	///

	support_re = ///
		^
		([A-Za-z]+)\:           # Country
		\s+(A|F)                # Supporting unit type
		\s+((?:\w+\s+)?(?:\w+)) # Supporter
		\s+Supports
		\s+(A|F)                # Supported unit type
		\s+((?:\w+\s+)?(?:\w+)) # Move from
		\s+\-
		\s+((?:\w+\s+)?(?:\w+)) # Move to
		$
	///

	return if matches = order.match(move_re)
		type    : 'MOVE'
		from    : matches[3]
		to      : matches[4]
		country : matches[1]
		utype   : matches[2] is 'A' and 'Army' or 'Fleet'
	else if matches = order.match hold_re
		type    : 'HOLD'
		from    : matches[3]
		country : matches[1]
		utype   : matches[2] is 'A' and 'Army' or 'Fleet'
	else if matches = order.match(convoy_re)
		type     : 'CONVOY'
		utype    : 'Fleet'
		convoyer : matches[2]
		from     : matches[3]
		to       : matches[4]
		country  : matches[1]
	else if matches = order.match(support_re)
		type      : 'SUPPORT'
		supporter : matches[3]
		utype     : matches[2] is 'A' and 'Army' or 'Fleet'
		from      : matches[5]
		to        : matches[6]
		country   : matches[1]

module.exports = parseOrder
