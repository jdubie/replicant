should = require('should')
async = require('async')
util = require('util')
request = require('request')

{TestUser} = require('lib/test_models')
{nano, nanoAdmin} = require('config')
{hash} = require('lib/helpers')
debug = require('debug')('replicant/test/func/like/delete_id')


describe 'yyyy DELETE /likes/:id', () ->

  # simple test - for now should just 403 (forbidden)

  user = new TestUser('delete_likes_id')
  ctime = mtime = 12345
  _like =
    _id: 'deletelike'
    type: 'like'
    name: user.name
    user_id: 'user2'
    swap_id: 'swap1'
    ctime: ctime
    mtime: mtime
    foo: 'bar'
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    # start webserver
    app = require('app')

    # insert like
    insertLike = (callback) ->
      mainDb.insert _like, (err, res) ->
        should.not.exist(err)
        _like._rev = res.rev
        callback()

    async.series [
      user.create
      insertLike
    ], ready

  it 'should return a 200', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/likes/#{_like._id}"
      headers: cookie: user.cookie
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
