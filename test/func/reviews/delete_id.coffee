should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')


describe 'DELETE /reviews/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _review =
    _id: 'deletereview'
    type: 'review'
    name: _username
    user_id: _userId
    review_type: 'swap'
    reviewee_id: 'user1_id'
    swap_id: 'swap1'
    rating: 1
    review: "NOT buttery."
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert review
    insertReview = (callback) ->
      mainDb.insert _review, (err, res) ->
        should.not.exist(err)
        _review._rev = res.rev
        callback()
    async.series [
      authUser
      insertReview
    ], ready


  after (finished) ->
    mainDb.destroy(_review._id, _review._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/reviews/#{_review._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'review\' type entry in lifeswap db', (done) ->
    mainDb.get _review._id, (err, review) ->
      should.not.exist(err)
      review.should.eql(_review)
      done()
