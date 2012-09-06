should = require('should')
util = require('util')
async = require('async')
request = require('request')

{TestLike} = require('lib/test_models')
{nanoAdmin} = require('config')


describe 'y GET /likes', () ->

  likes = (new TestLike(id) for id in ['get_likes_1', 'get_likes_2'])

  before (ready) ->
    app = require('app')
    create = (like, callback) -> like.create(callback)
    async.map(likes, create, ready)

  after (finished) ->
    destroy = (like, callback) -> like.destroy(callback)
    async.map(likes, destroy, finished)

  it 'should provide a list of all the correct likes', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/likes'
      json: true
    request opts, (err, res, likeDocs) ->
      should.not.exist(err)
      likeDocs.should.eql((like.attributes() for like in likes))
      done()
