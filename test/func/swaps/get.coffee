should = require('should')
util = require('util')
request = require('request')
{nano} = require('../../../config')
{createUser} = require('../../../lib/replicant')


describe 'GET /user', () ->

  swapsNano = []

  ###
    Make sure that user's db doesn't exist
  ###
  before (ready) ->
    # start webserver
    app = require('../../../app')

    db = nano.db.use('lifeswap')
    opts = include_docs: true
    db.view 'lifeswap', 'swaps', opts, (err, res) ->
      should.not.exist(err)
      swapsNano = (row.doc for row in res.rows)
      ready()

  it 'should provide a list of all the correct swaps', (done) ->
    request.get 'http://localhost:3001/swaps', (err, res, swaps) ->
      should.not.exist(err)
      swaps = JSON.parse(swaps)
      swaps.should.eql(swapsNano)
      done()
