should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'DELETE /likes/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  ## from toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  ctime = mtime = 12345
  _like =
    _id: 'deletelike'
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
    app = require('../../../app')

    ## authenticate user
    authUser = (callback) ->
      nano.auth _username, _password, (err, body, headers) ->
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

    async.series [
      authUser
      insertLike
    ], ready


  after (finished) ->
    ## destroy like
    mainDb.get _like._id, (err, like) ->
      should.not.exist(err)
      mainDb.destroy(like._id, like._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/likes/#{_like._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'like\' type entry in lifeswap db', (done) ->
    mainDb.get _like._id, (err, like) ->
      should.not.exist(err)
      like.should.eql(_like)
      done()
