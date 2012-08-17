should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'POST /likes', () ->

  _like =
    _id: 'postlikes'
    type: 'like'
  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    ready()


  after (finished) ->
    mainDb.destroy(_like._id, _like._rev, finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/swaps"
      json: _like
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        _like[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get _like._id, (err, like) ->
      should.not.exist(err)
      like.should.eql(_like)
      done()
