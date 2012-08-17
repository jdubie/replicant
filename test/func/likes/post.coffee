should = require('should')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')


describe 'POST /likes', () ->

  _userId = 'user2'
  _password = 'pass2'
  ctime = mtime = 12345
  _like =
    _id: 'postlikes'
    type: 'like'
    name: 'user2'
    user_id: 'user2'
    swap_id: 'swap1'
    ctime: ctime
    mtime: mtime
    foo: 'bar'
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')

    ## authenticate user
    nano.auth _userId, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      ready()


  after (finished) ->
    mainDb.destroy(_like._id, _like._rev, finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/swaps"
      json: _like
      headers: cookie: cookie
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
