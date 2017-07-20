exports.CycleException = class CycleException extends Error
	constructor: (@cycle) ->

exports.NotImplementedException = class NotImplementedException extends Error
	constructor: (@cycle) ->
