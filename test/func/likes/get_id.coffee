should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'GET /likes/:id', () ->

  ctime = mtime = 12345
  _like =
    _id: 'getlikeid'
    type: 'like'
    name: '-hash2-'
    user_id: 'user2'
    swap_id: 'swap1'
    ctime: ctime
    mtime: mtime
    foo: 'bar'

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert like
    mainDb.insert _like, _like._id, (err, res) ->
      _like._rev = res.rev
      ready()

  after (finished) ->
    mainDb.destroy(_like._id, _like._rev, finished)

  it 'should get the correct like', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/likes/#{_like._id}"
      json: true
    request opts, (err, res, like) ->
      should.not.exist(err)
      like.should.eql(_like)
      done()

  it 'should give error, reason, and statusCode on bad get', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/likes/doesnt_exist"
      json: true
    request opts, (err, res, body) ->
      should.not.exist(err)
      should.exist(res)
      res.should.have.property('statusCode', 404)
      body.should.have.keys('error', 'reason')
      body.error.should.eql('not_found')
      body.reason.should.eql('missing')
      done()

