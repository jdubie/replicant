should = require('should')
util = require('util')
request = require('request')

{nano} = require('config')
{createUser} = require('lib/replicant')


describe 'GET /swaps', () ->

  swapsNano = []

  before (ready) ->
    # start webserver
    app = require('app')

    db = nano.db.use('lifeswap')
    opts =
      key: 'swap'
      include_docs: true
    db.view 'lifeswap', 'docs_by_type', opts, (err, res) ->
      should.not.exist(err)
      swapsNano = (row.doc for row in res.rows)
      ready()

  it 'should provide a list of all the correct swaps', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/swaps'
      json: true
    request opts, (err, res, swaps) ->
      should.not.exist(err)
      swaps.should.eql(swapsNano)
      done()
