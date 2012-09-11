should = require('should')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')
{TestUser, TestLike} = require('lib/test_models')


describe 'PUT /likes/:id', () ->

  user = new TestUser('put_likes_id_user')
  like = new TestLike('putlikesid', user)
  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    app = require('app')
    async.parallel([user.create, like.create], ready)

  after (finished) ->
    async.parallel([user.destroy, like.destroy], finished)

  it 'should return 403 (cannot modify likes)', (done) ->
    oldFoo = like.foo
    like.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/likes/#{like._id}"
      json: like.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(403)
      like.foo = oldFoo
      done()

  it 'should not modify the document in the DB', (done) ->
    mainDb.get like._id, (err, likeDoc) ->
      should.not.exist(err)
      likeDoc.should.eql(like.attributes())
      done()
