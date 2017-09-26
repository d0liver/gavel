# Node
fs   = require 'fs'
YAML = require 'yamljs'

# Local
{UserException, ResolverException} = require './Exceptions'
debug                              = require('./debug') 'DATC'
Board                              = require './Board'
PathFinder                         = require './PathFinder'
Engine                             = require './Engine'
TestRunner                         = require './TestRunner'

minimist = require 'minimist'

argv = minimist process.argv[2..], boolean: ['builds', 'moves', 'retreats', 'all']

{outcomes: {SUCCEEDS, FAILS, ILLEGAL, EXISTS}} = require './enums'

datc = (board, pfinder) ->
	engine = Engine board, pfinder
	test_runner = new TestRunner engine, board, pfinder

	if argv.moves or argv.all
		console.log "Testing Moves"
		console.log "-------------"
		test_runner.moves test for test in YAML.load './tests/moves.yml'
	if argv.retreats or argv.all
		console.log "Testing Retreats"
		console.log "----------------"
		test_runner.retreats test for test in YAML.load './tests/retreats.yml'
	if argv.builds or argv.all
		console.log "Testing Builds"
		console.log "----------------"
		test_runner.builds test for test in YAML.load './tests/builds.yml'

# Catch failed promises
process.on 'unhandledRejection', (reason, p) ->
  debug 'Unhandled Rejection at: ', p, 'reason: ', reason

try
	gdata = JSON.parse fs.readFileSync './test_game_data.json'
	vdata = JSON.parse fs.readFileSync './test_variant_data.json'
	vdata.map_data = JSON.parse vdata.map_data
catch e
	console.log 'Failed to read sample game from test_game_data.json'

	debug e
	process.exit 1

board = Board gdata, vdata
pfinder = new PathFinder board
datc board, pfinder
