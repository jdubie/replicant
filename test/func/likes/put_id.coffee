should = require('should')
async = require('async')
util = require('util')
request = require('request')

{TestUser} = require('lib/test_models')
{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')


describe 'yyyy PUT /likes/:id', () ->

  ## from toy data
  user = new TestUser('put_likes_id')
  ctime = mtime = 12345
  _like =
    _id: 'putlikesid'
    type: 'like'
    name: user.name
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
    insertLike = (callback) ->
      mainDb.insert _like, (err, res) ->
        should.not.exist(err)
        _like._rev = res.rev
        callback()

    ## in parallel
    async.series [
      user.create
      insertLike
    ], ready


  after (finished) ->
    ## destroy like
    mainDb.destroy _like._id, _like._rev, (err) ->
      return finished(err) if err
      user.destroy(finished)

  it 'should return 403 (cannot modify likes)', (done) ->
    oldFoo = _like.foo
    _like.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/likes/#{_like._id}"
      json: _like
      headers: cookie: user.cookie
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
