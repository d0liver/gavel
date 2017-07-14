# These were the test cases that were used during the initial development of
# the resolver. The DATC cases should be much more comprehensive.
basic_test_cases =
	move_depends:
		orders: [
			type: 'MOVE'
			from: 'A'
			to: 'B'
			country: 'BigBird'
		,
			type: 'MOVE'
			from: 'B'
			to: 'C'
			country: 'Boss'
		,
			type: 'MOVE'
			from: 'C'
			to: 'D'
			country: 'Boss'
		]
		units:
			A: type: 'Army'
			B: type: 'Army'
			C: type: 'Army'
		expects: [true, true, true]

	support:
		orders: [
			type: 'MOVE'
			from: 'A'
			to: 'C'
			country: 'BigBird'
		,
			type: 'MOVE'
			from: 'B'
			to: 'C'
			country: 'Boss'
		,
			type: 'SUPPORT'
			supporter: 'D'
			from: 'B'
			to: 'C'
			country: 'Boss'
		]
		units:
			A: type: 'Army'
			B: type: 'Army'
			D: type: 'Army'
		expects: [false, true, true]
	cyclic_move:
		orders: [
			type: 'MOVE'
			from: 'A'
			to: 'B'
			country: 'BigBird'
		,
			type: 'MOVE'
			from: 'B'
			to: 'C'
			country: 'Boss'
		,
			type: 'MOVE'
			from: 'C'
			to: 'A'
			country: 'Boss'
		,
			type: 'SUPPORT'
			country: 'BigBird'
			from: 'A'
			to: 'B'
			supporter: 'D'
		]
		units:
			A: type: 'Army'
			B: type: 'Army'
			C: type: 'Army'
			D: type: 'Army'
		expects: [true, true, true, true]
	convoy_paradox:
		orders: [
				type: 'SUPPORT'
				from: 'Aegean'
				to: 'Ionian'
				supporter: 'Greece'
				country: 'Turkey'
			,
				type: 'SUPPORT'
				from: 'Aegean'
				to: 'Ionian'
				supporter: 'Albania'
				country: 'Austria'
			,
				type: 'MOVE'
				from: 'Aegean'
				to: 'Ionian'
				country: 'Turkey'
			,
				type: 'CONVOY'
				convoyer: 'Ionian'
				from: 'Tunis'
				to: 'Greece'
				country: 'Italy'
			,
				type: 'MOVE'
				from: 'Tunis'
				to: 'Greece'
				country: 'Italy'
		]
		units:
			Greece: type: 'Fleet'
			Albania: type: 'Fleet'
			Aegean: type: 'Fleet'
			Ionian: type: 'Fleet'
			Tunis: type: 'Army'
		expects: [true, true, true, false, false]


# Show all orders first
testCases = ->
	# Prevent a bunch of extra noise when running the tests.

	for title,{orders, units, expects} of basic_test_cases
		console.log "\nRunning test: ", title
		resolver = Resolver(orders, units, true)

		console.log(resolver.describe(order)) for order in orders
		console.log()

		resolver.resolve(order)

		console.log(resolver.describe(order)) for order in orders

		for order,i in orders when order.succeeds isnt expects[i]
			console.log "Test failed: ", title
			return

	console.log "All tests passed successfully."

testCases()
