should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')


describe 'PUT /reviews/:id', () ->

  ## from toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _review =
    _id: 'putreviewsid'
    type: 'review'
    name: _username
    user_id: _userId
    review_type: 'swap'
    reviewee_id: 'user1_id'
    swap_id: 'swap1'
    rating: 1
    review: "NOT a buttery swap."
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

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
    ## in parallel
    async.series [
      authUser
      insertReview
    ], ready


  after (finished) ->
    ## destroy review
    mainDb.destroy(_review._id, _review._rev, finished)


  it 'should return _rev and mtime', (done) ->
    oldFoo = _review.foo
    _review.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/reviews/#{_review._id}"
      json: _review
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        _review[key] = val
      done()

  it 'should modify the document in the DB', (done) ->
    mainDb.get _review._id, (err, review) ->
      should.not.exist(err)
      review.should.eql(_review)
      done()
