should = require('should')
util = require('util')
async = require('async')
request = require('request')

{TestReview} = require('lib/test_models')
{nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'yyyy GET /reviews', () ->

  reviews = (new TestReview(id) for id in ['get_review_1', 'get_review_2'])

  before (ready) ->
    app = require('app')
    create = (review, callback) -> review.create(callback)
    async.map(reviews, create, ready)

  after (finished) ->
    destroy = (review, callback) -> review.destroy(callback)
    async.map(reviews, destroy, finished)

  it 'should provide a list of all the correct reviews', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/reviews'
      json: true
    request opts, (err, res, reviewDocs) ->
      should.not.exist(err)
      reviewDocs.should.eql((review.attributes() for review in reviews))
      done()
