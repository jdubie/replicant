should = require('should')
async = require('async')
request = require('request')

{TestUser, TestReview} = require('lib/test_models')


describe 'GET /reviews', () ->

  user = new TestUser('get_reviews_user')
  reviews = (new TestReview(id, user) for id in ['get_review_1', 'get_review_2'])

  before (ready) ->
    app = require('app')
    create = (review, callback) -> review.create(callback)
    async.parallel [
      user.create
      (cb) -> async.map(reviews, create, cb)
    ], ready

  after (finished) ->
    destroy = (review, callback) -> review.destroy(callback)
    async.parallel [
      user.destroy
      (cb) -> async.map(reviews, destroy, cb)
    ], finished

  it 'should provide a list of all the correct reviews', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/reviews'
      json: true
    request opts, (err, res, reviewDocs) ->
      should.not.exist(err)
      reviewDocs.should.eql((review.attributes() for review in reviews))
      done()
