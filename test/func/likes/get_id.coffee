should  = require('should')
async   = require('async')
request = require('request')

{TestUser, TestLike} = require('lib/test_models')
{nanoAdmin} = require('config')


describe 'GET /likes/:id', () ->

  user = new TestUser('get_likes_id_user')
  like = new TestLike('get_likes_id', user)

  before (ready) ->
    app = require('app')
    async.parallel([user.create, like.create], ready)

  after (finished) ->
    async.parallel([user.destroy, like.destroy], finished)

  it 'should get the correct like', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/likes/#{like._id}"
      json: true
    request opts, (err, res, likeDoc) ->
      should.not.exist(err)
      likeDoc.should.eql(like.attributes())
      done()

  it 'should give error, reason, and statusCode on bad get', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/likes/doesnt_exist"
      json: true
    request opts, (err, res, body) ->
      should.not.exist(err)
      should.exist(res)
      res.should.have.property('statusCode', 404)
      body.should.have.keys('error', 'reason')
      body.error.should.eql('not_found')
      body.reason.should.eql('missing')
      done()

