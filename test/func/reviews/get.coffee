should = require('should')
util = require('util')
async = require('async')
request = require('request')

{nanoAdmin, nano} = require('config')


describe 'GET /reviews', () ->

  _reviews = [
    {
      _id: 'getreviews1'
      type: 'review'
    }
    {
      _id: 'getreviews2'
      type: 'review'
    }
  ]

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    # start webserver
    app = require('app')
    ## insert review
    insertReview = (review, cb) ->
      mainDb.insert review, review._id, (err, res) ->
        review._rev = res.rev
        cb()
    async.map(_reviews, insertReview, ready)

  after (finished) ->
    destroyReview = (review, cb) ->
      mainDb.destroy(review._id, review._rev, cb)
    async.map(_reviews, destroyReview, finished)

  it 'should provide a list of all the correct reviews', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/reviews'
      json: true
    request opts, (err, res, reviews) ->
      should.not.exist(err)
      reviews.should.eql(_reviews)
      done()
