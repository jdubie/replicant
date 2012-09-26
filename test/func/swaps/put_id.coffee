should  = require('should')
async   = require('async')
request = require('request')

config  = require('config')
{TestUser, TestSwap} = require('lib/test_models')


describe 'PUT /swaps/:id', () ->

  host      = new TestUser('put_swaps_id_host')
  constable = new TestUser('put_swaps_id_const', roles: ['constable'])
  swap      = new TestSwap('put_swaps_id', host, description: 'foo')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert host, constable, and swap
    async.parallel [
      host.create
      constable.create
      swap.create
    ], ready

  after (finished) ->
    ## destroy host, constable, and swap
    async.parallel [
      host.destroy
      constable.destroy
      swap.destroy
    ], finished

  describe 'host change status \'pending\' => \'approved\'', () ->
    it 'should 200 with correct values', (done) ->
      oldStatus = swap.status   # (i.e. 'pending')
      swap.status = 'approved'
      opts =
        method: 'PUT'
        url: "http://localhost:3001/swaps/#{swap._id}"
        json: swap.attributes()
        headers: cookie: host.cookie
      request opts, (err, res, body) ->
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property('status')
        swap.status = oldStatus
        done()

  describe 'put the swap document correctly', (done) ->
    it 'should return correct values', (done) ->
      swap.description = 'bar'
      opts =
        method: 'PUT'
        url: "http://localhost:3001/swaps/#{swap._id}"
        json: swap.attributes()
        headers: cookie: host.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        body.should.have.keys(['_rev', 'mtime'])
        for key, val of body
          swap[key] = val
        done()

    it 'should make the change in couch', (done) ->
      db = config.db.main()
      db.get swap._id, (err, swapDoc) ->
        should.not.exist(err)
        swapDoc.should.eql(swap.attributes())
        done()

  describe 'constable change status', () ->
    it 'should 200 with correct values', (done) ->
      swap.status = 'approved'
      opts =
        method: 'PUT'
        url: "http://localhost:3001/swaps/#{swap._id}"
        json: swap.attributes()
        headers: cookie: constable.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        body.should.have.keys(['_rev', 'mtime'])
        for key, val of body
          swap[key] = val
        done()

    it 'should make the change in couch', (done) ->
      db = config.db.main()
      db.get swap._id, (err, swapDoc) ->
        should.not.exist(err)
        swapDoc.should.eql(swap.attributes())
        done()


  describe 'host change status \'approved\' => \'inactive\'', () ->
    it 'should 200 with correct values', (done) ->
      swap.status = 'inactive'
      opts =
        method: 'PUT'
        url: "http://localhost:3001/swaps/#{swap._id}"
        json: swap.attributes()
        headers: cookie: host.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        body.should.have.keys(['_rev', 'mtime'])
        for key, val of body
          swap[key] = val
        done()

    it 'should make the change in couch', (done) ->
      db = config.db.main()
      db.get swap._id, (err, swapDoc) ->
        should.not.exist(err)
        swapDoc.should.eql(swap.attributes())
        done()

  describe 'host change status \'inactive\' => \'approved\'', () ->
    it 'should 200 with correct values', (done) ->
      swap.status = 'approved'
      opts =
        method: 'PUT'
        url: "http://localhost:3001/swaps/#{swap._id}"
        json: swap.attributes()
        headers: cookie: host.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        body.should.have.keys(['_rev', 'mtime'])
        for key, val of body
          swap[key] = val
        done()

    it 'should make the change in couch', (done) ->
      db = config.db.main()
      db.get swap._id, (err, swapDoc) ->
        should.not.exist(err)
        swapDoc.should.eql(swap.attributes())
        done()
