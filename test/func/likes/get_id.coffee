should = require('should')
util = require('util')
request = require('request')

{TestLike} = require('lib/test_models')
{nanoAdmin} = require('config')


describe 'yyyy GET /likes/:id', () ->

  like = new TestLike('get_likes_id')

  before (ready) ->
    app = require('app')
    like.create(ready)

  after (finished) ->
    like.destroy(finished)

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

