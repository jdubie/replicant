should = require('should')
util = require('util')
request = require('request')
async = require('async')

{TestUser, TestReview} = require('lib/test_models')
{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')


describe 'y POST /reviews', () ->

  user = new TestUser('post_reviews_user')
  review = new TestReview('post_reviews', user)
  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    async.parallel([user.create], ready)

  after (finished) ->
    async.parallel([user.destroy, review.destroy], finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/reviews"
      json: review.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        review[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get review._id, (err, reviewDoc) ->
      should.not.exist(err)
      reviewDoc.should.eql(review.attributes())
      done()
