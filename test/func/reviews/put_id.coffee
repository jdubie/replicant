should  = require('should')
async   = require('async')
request = require('request')

{nanoAdmin} = require('config')
{TestUser, TestReview} = require('lib/test_models')


describe 'PUT /reviews/:id', () ->

  user = new TestUser('put_reviews_id_user')
  review = new TestReview('put_reviews_id', user)
  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    app = require('app')
    async.parallel([user.create, review.create], ready)

  after (finished) ->
    async.parallel([user.destroy, review.destroy], finished)

  it 'should return _rev and mtime', (done) ->

    # modify review
    review.review = 'im the new kid in town'

    opts =
      method: 'PUT'
      url: "http://localhost:3001/reviews/#{review._id}"
      json: review.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        review[key] = val
      done()

  it 'should modify the document in the DB', (done) ->
    mainDb.get review._id, (err, reviewDoc) ->
      should.not.exist(err)
      reviewDoc.should.eql(review.attributes())
      done()
