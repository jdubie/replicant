should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')
{TestUser} = require('lib/test_models')
{TestReview} = require('lib/test_models')


describe 'yyyy DELETE /reviews/:id', () ->

  user = new TestUser('delete_reviews_id_user')
  review = new TestReview('delete_reviews_id', user)

  mainDb = config.nanoAdmin.db.use('lifeswap')
  usersDb = config.nanoAdmin.db.use('_users')

  before (ready) ->
    app = require('app')
    async.parallel([user.create, review.create], ready)

  after (finished) ->
    async.parallel([user.destroy, review.destroy], finished)

  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/reviews/#{review._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'review\' type entry in lifeswap db', (done) ->
    mainDb.get review._id, (err, review) ->
      should.not.exist(err)
      review.should.eql(review)
      done()
