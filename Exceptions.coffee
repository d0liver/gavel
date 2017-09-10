exports.UserException = class UserException extends Error
exports.CycleException = class CycleException extends UserException
	constructor: (@cycle, @dependencies) ->
		super()

exports.NotImplementedException = class NotImplementedException extends UserException
	constructor: (@cycle) ->
		super()
