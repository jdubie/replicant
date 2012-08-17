should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'GET /likes/:id', () ->

  _like =
    _id: 'getlikeid'
    type: 'like'

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
