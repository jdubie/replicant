should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')


describe 'PUT /likes/:id', () ->

  ## from toy data
  _userId = 'user2'
  _password = 'pass2'
  ctime = mtime = 12345
  _like =
    _id: 'putlikesid'
    type: 'like'
    name: _userId
    user_id: 'user2'
    swap_id: 'swap1'
    ctime: ctime
    mtime: mtime
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert like
    insertLike = (callback) ->
      mainDb.insert _like, (err, res) ->
        should.not.exist(err)
        _like._rev = res.rev
        callback()
    ## in parallel
    async.series [
      authUser
      insertLike
    ], ready


  after (finished) ->
    ## destroy like
    mainDb.destroy(_like._id, _like._rev, finished)


  it 'should return 403 (cannot modify likes)', (done) ->
    oldFoo = _like.foo
    _like.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/likes/#{_like._id}"
      json: _like
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(403)
      _like.foo = oldFoo
      done()

  it 'should not modify the document in the DB', (done) ->
    mainDb.get _like._id, (err, like) ->
      should.not.exist(err)
      like.should.eql(_like)
      done()
