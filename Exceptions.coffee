exports.CycleException = class CycleException extends Error
	constructor: (@cycle, @dependencies) ->

exports.NotImplementedException = class NotImplementedException extends Error
	constructor: (@cycle) ->
