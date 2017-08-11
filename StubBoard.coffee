# Stub implementation for the board for use with the build tests.
StubBoard = (board, adjustments) ->
	self = {}

	# Canned response for the adjustments
	self.adjustments = -> Object.assign {}, adjustments

	# Everything else just forwards to the actual board module
	self.addOrder = board.addOrder.bind board
	self.homeCenters = board.homeCenters.bind board
	self.region = board.region.bind board
	self.adjacencies = board.adjacencies.bind board
	self.hasCoast = board.hasCoast.bind board
	self.canConvoy = board.canConvoy.bind board
	self.canSupport = board.canSupport.bind board
	self.canMove = board.canMove.bind board
	self.setContested = board.setContested.bind board
	self.dislodgedUnits = board.dislodgedUnits.bind board
	self.setDislodger = board.setDislodger.bind board
	self.removeDislodger = board.removeDislodger.bind board
	self.removeUnit = board.removeUnit.bind board
	self.addUnit = board.addUnit.bind board
	self.clearUnits = board.clearUnits.bind board
	self.units = board.units.bind board

	return self

module.exports = StubBoard
