{orders: {BUILD, MOVE, SUPPORT, CONVOY, HOLD}} = require './enums'

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

	build_re = ///
		([A-Za-z]+)\:                 # Country
		\s+Build
		\s+(A|F)
		\s+((?:[\w-]+\s+)*(?:[\w-]+)) # Build region
		(?:\(([\w-]+)\))?             # Optional coast
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
		type        : matches[5] is 'Convoys' and CONVOY or SUPPORT
		from_utype  : matches[6] is 'A' and 'Army' or 'Fleet'
		from        : matches[7]
		from_coast  : coastName matches[8]
		to          : matches[9] ? matches[11] # Either a dest region or 'Hold'
		to_coast    : coastName matches[10]
	else if matches = order.match(move_re)
		# via convoy can't be easily distinguished from the destination name
		# using regular expressions. Instead, we just check for it here and
		# strip it out if necessary.
		if match = / (by|via) [Cc]onvoy/.exec matches[5]
			via_convoy = true
			matches[5] = matches[5].slice 0, match.index
		else
			via_convoy = false

		type       : MOVE
		country    : matches[1]
		utype      : matches[2] is 'A' and 'Army' or 'Fleet'
		actor      : matches[3]
		from       : matches[3]
		from_coast : coastName matches[4]
		to         : matches[5]
		to_coast   : coastName matches[6]
		via_convoy : via_convoy
	else if matches = order.match hold_re
		type        : HOLD
		country     : matches[1]
		utype       : matches[2] is 'A' and 'Army' or 'Fleet'
		actor       : matches[3]
		from        : matches[3]
		actor_coast : coastName matches[4]
		from_coast  : coastName matches[4]
	else if matches = order.match build_re
		type: BUILD
		country: matches[1]
		utype: matches[2] is 'A' and 'Army' or 'Fleet'
		actor: matches[3]
		region: matches[3]
		region_coast: matches[4]

module.exports = parseOrder
