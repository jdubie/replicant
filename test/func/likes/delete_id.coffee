should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin} = require('config')
{hash} = require('lib/helpers')
debug = require('debug')('replicant/test/func/like/delete_id')


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
    name: _username
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

  it 'should return a 200', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/likes/#{_like._id}"
      headers: cookie: cookie
      json: _like
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.equal(200)
      body.should.have.property('ok', true)
      body.should.have.property('id', _like._id)
      done()

  it 'should actually remove document', (done) ->
    mainDb.get _like._id, (err, like) ->
      should.not.exist(like)
      should.exist(err)
      err.should.have.property('status_code', 404)
      done()
