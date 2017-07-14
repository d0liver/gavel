var fs = require('fs');
YAML = require('yamljs');

module.exports = (orders_text, formats) => {
	var self = {}, formats, orders = [];

	if (formats === undefined)
		try {
			formats = YAML.load('./order_formats.yaml');
		}
		catch (e) {
			throw new Error (
				'Unable to get default order formats from'+
				'order_formats.yaml. The parser error message was: '+ e.message
			);
		}

	// Parse the orders in orders_text using the formats specified and return
	// the resulting object.
	self.parse = => {
		for(order_type in formats) {
			formats[order_type].find((format) => {
				if (self.matches()
			});
		}
	};

	/* TODO: Maybe validate the incoming formats */
	self.setFormats = (f) => {
		formats = f;
	};

	self.matches = (order_text, format) => {
	};

	var parseOrders = (txt) => {
		var lines = txt.split(/[\r\n]+);

		orders = lines.map((line) => {
		});
	};

	return self;
};

var parseOrder = (order_text) => {
	pieces = order_text.split(\s+);

	// Move orders have the form 'A Moves To B'
	if (/moves/i.test(pieces[1]) && pieces.length == 4)
		[from, , , to] = pieces;
	// Support orders have the form 'A Supports B To C'
	else if (/supports/i.test(pieces[1]) && pieces.length == 5
};

var orderType = ()
move_re = /^([A-Za-z]+)\:\s+(?:A|F)\s+((?:\w+\s+)?(?:\w+))\s+\-\s+((?:\w+\s+)?(?:\w+))$/

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
