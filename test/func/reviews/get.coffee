should = require('should')
util = require('util')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'GET /reviews', () ->

  _ctime = _mtime = 12345
  _reviews = [
    {
      _id: 'getreviews1'
      type: 'review'
      name: hash('user1@test.com')
      user_id: 'user1_id'
      review_type: 'guest'
      reviewee_id: 'user2_id'
      rating: 1
      review: "NOT a chill person."
      ctime: _ctime
      mtime: _mtime
      foo: 'bar'
    }
    {
      _id: 'getreviews2'
      type: 'review'
      name: hash('user2@test.com')
      user_id: 'user2_id'
      review_type: 'swap'
      reviewee_id: 'user1_id'
      swap_id: 'swap1'
      rating: 1
      review: "NOT a buttery swap."
      ctime: _ctime
      mtime: _mtime
      baz: 'bag'
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
