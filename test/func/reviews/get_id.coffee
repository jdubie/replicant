should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

{TestUser, TestReview} = require('lib/test_models')


describe 'GET /reviews/:id', () ->

  user = new TestUser('get_review_id_user')
  review = new TestReview('get_review_id', user)

  before (ready) ->
    app = require('app')
    async.parallel([user.create, review.create], ready)

  after (finished) ->
    async.parallel([user.destroy, review.destroy], finished)

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
