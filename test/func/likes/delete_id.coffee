should = require('should')
async = require('async')
util = require('util')
request = require('request')

{TestUser, TestLike} = require('lib/test_models')
{nano, nanoAdmin} = require('config')
{hash} = require('lib/helpers')
debug = require('debug')('replicant/test/func/like/delete_id')


describe 'y DELETE /likes/:id', () ->

  user = new TestUser('delete_likes_id_user')
  like = new TestLike('delete_likes_id', user)

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    app = require('app')
    async.parallel([user.create, like.create], ready)

  after (finished) ->
    async.parallel([user.destroy, like.destroy], finished)

  it 'should return a 200', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/likes/#{like._id}"
      headers: cookie: user.cookie
      json: like
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.equal(200)
      body.should.have.property('ok', true)
      body.should.have.property('id', like._id)
      done()

  it 'should actually remove document', (done) ->
    mainDb.get like._id, (err, likeDoc) ->
      should.not.exist(likeDoc)
      should.exist(err)
      err.should.have.property('status_code', 404)
      done()
