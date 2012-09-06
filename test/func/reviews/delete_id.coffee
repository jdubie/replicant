should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')
{TestUser} = require('lib/test_models')


describe 'yyyy DELETE /reviews/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  user = new TestUser('delete_reviews_id')
  _password = 'pass2'
  _ctime = _mtime = 12345
  _review =
    _id: 'deletereview'
    type: 'review'
    name: user.name
    user_id: user._id
    review_type: 'swap'
    reviewee_id: 'user1_id'
    swap_id: 'swap1'
    rating: 1
    review: "NOT buttery."
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')

  before (ready) ->

    # start webserver
    app = require('app')

    # insert review
    insertReview = (callback) ->
      mainDb.insert _review, (err, res) ->
        should.not.exist(err)
        _review._rev = res.rev
        callback()
        
    async.series [
      user.create
      insertReview
    ], ready

  after (finished) ->
    mainDb.destroy _review._id, _review._rev, (err) ->
      return finished(err) if err
      user.destroy(finished)

  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/reviews/#{_review._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'review\' type entry in lifeswap db', (done) ->
    mainDb.get _review._id, (err, review) ->
      should.not.exist(err)
      review.should.eql(_review)
      done()
