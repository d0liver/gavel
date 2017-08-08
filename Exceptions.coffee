exports.CycleException = class CycleException extends Error
	constructor: (@cycle, @args) ->

exports.NotImplementedException = class NotImplementedException extends Error
	constructor: (@cycle) ->
