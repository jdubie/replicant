should = require('should')
util = require('util')
async = require('async')
request = require('request')

{TestUser, TestLike} = require('lib/test_models')
{nanoAdmin} = require('config')


describe 'GET /likes', () ->

  user = new TestUser('get_likes_user')
  likes = (new TestLike(id, user) for id in ['get_likes_1', 'get_likes_2'])

  before (ready) ->
    app = require('app')
    create = (like, callback) -> like.create(callback)
    async.parallel [
      user.create
      (cb) -> async.map(likes, create, cb)
    ], ready

  after (finished) ->
    destroy = (like, callback) -> like.destroy(callback)
    async.parallel [
      user.destroy
      (cb) -> async.map(likes, destroy, cb)
    ], finished

  it 'should provide a list of all the correct likes', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/likes'
      json: true
    request opts, (err, res, likeDocs) ->
      should.not.exist(err)
      likeDocs.should.eql((like.attributes() for like in likes))
      done()
