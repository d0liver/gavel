parseOrder = (order) ->
	coastName = (abbr) ->
		map = 
			nc: 'North'
			sc: 'South'
			ec: 'East'
			wc: 'West'
		return map[abbr]

	move_re = ///
		^
		([A-Za-z]+)\:                 # Country
		\s+(A|F)                      # Unit type
		\s+((?:[\w-]+\s+)*(?:[\w-]+)) # Move from
		(?:\(([\w-]+)\))?             # Optional coast
		\s+\-
		\s+((?:[\w-]+\s+)*(?:[\w-]+)) # Move to
		(?:\(([\w-]+)\))?             # Optional coast
		$
	///

	hold_re = ///
		^
		([A-Za-z]+)\:                 # Country
		\s+(A|F)                      # Unit type
		\s+((?:[\w-]+\s+)*(?:[\w-]+)) # Unit region
		(?:\(([\w-]+)\))?             # Optional coast
		\s+Hold
		$
	///

	support_convoy_re = ///
		^
		([A-Za-z]+)\:                 # Country
		\s+(A|F)                      # Supporting or convoying unit type
		\s+((?:[\w-]+\s+)*(?:[\w-]+)) # Supporting or convoying unit region
		(?:\(([\w-]+)\))?             # Optional coast
		\s+(Supports|Convoys)         # Support or Convoy
		\s+(A|F)                      # Supported unit type
		\s+((?:[\w-]+\s+)*(?:[\w-]+)) # Move from
		(?:\(([\w-]+)\))?             # Optional coast
		(?:
			\s+\-
			\s+((?:[\w-]+\s+)*(?:[\w-]+)) # Move to
			(?:\(([\w-]+)\))?          # Optional coast
			|\s+(Hold)
		)
		$
	///

	# When we do the parsing we want to parse the longer order formats first
	# otherwise the shorter order formats (like move and hold) will eat the
	# order assuming it's part of the name and claim it has a match. Support
	# and convoy regexes must be combined for the same reason.
	return if matches = order.match(support_convoy_re)
		country     : matches[1]
		utype       : matches[2] is 'A' and 'Army' or 'Fleet'
		actor       : matches[3]
		actor_coast : coastName matches[4]
		type        : matches[5] is 'Convoys' and 'CONVOY' or 'SUPPORT'
		from_utype  : matches[6] is 'A' and 'Army' or 'Fleet'
		from        : matches[7]
		from_coast  : coastName matches[8]
		to          : matches[9] ? matches[11] # Either a dest region or 'Hold'
		to_coast    : coastName matches[10]
	else if matches = order.match(move_re)
		type       : 'MOVE'
		country    : matches[1]
		utype      : matches[2] is 'A' and 'Army' or 'Fleet'
		actor      : matches[3]
		from       : matches[3]
		from_coast : coastName matches[4]
		to         : matches[5]
		to_coast   : coastName matches[6]
	else if matches = order.match hold_re
		type        : 'HOLD'
		country     : matches[1]
		utype       : matches[2] is 'A' and 'Army' or 'Fleet'
		actor       : matches[3]
		from        : matches[3]
		actor_coast : coastName matches[4]
		from_coast  : coastName matches[4]

module.exports = parseOrder
