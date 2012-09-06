should = require('should')
util = require('util')
request = require('request')

{TestReview} = require('lib/test_models')
{nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'y GET /reviews/:id', () ->

  review = new TestReview('get_review_id')

  before (ready) ->
    app = require('app')
    review.create(ready)

  after (finished) -> review.destroy(finished)

  it 'should get the correct review', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/reviews/#{review._id}"
      json: true
    request opts, (err, res, reviewDoc) ->
      should.not.exist(err)
      reviewDoc.should.eql(review.attributes())
      done()

  it 'should give error, reason, and statusCode on bad get', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/reviews/doesnt_exist"
      json: true
    request opts, (err, res, body) ->
      should.not.exist(err)
      should.exist(res)
      res.should.have.property('statusCode', 404)
      body.should.have.keys('error', 'reason')
      body.error.should.eql('not_found')
      body.reason.should.eql('missing')
      done()
