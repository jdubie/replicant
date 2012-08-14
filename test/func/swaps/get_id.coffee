should = require('should')
util = require('util')
request = require('request')

{nano} = require('config')
{createUser} = require('lib/replicant')


describe 'GET /swaps/:id', () ->

  someSwap = null

  before (ready) ->
    ## start webserver
    app = require('../../../app')

    ## get one of the swaps (the first from the 'swaps' view)
    db = nano.db.use('lifeswap')
    opts = include_docs: true
    db.view 'lifeswap', 'swaps', opts, (err, res) ->
      should.not.exist(err)
      someSwap = res.rows[0].doc
      ready()

  it 'should get the correct swap', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/swaps/#{someSwap._id}"
      json: true
    request opts, (err, res, swapDoc) ->
      should.not.exist(err)
      swapDoc.should.eql(someSwap)
      done()
