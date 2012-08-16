should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl} = require('config')


describe 'PUT /reviews/:id', () ->

  ## from toy data
  _userId = 'user2'
  _password = 'pass2'
  _review =
    _id: 'putreviewsid'
    type: 'review'
    name: _userId
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
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


  it 'should 403 because should not be able to modify reviews', (done) ->
    oldFoo = _review.foo
    _review.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/reviews/#{_review._id}"
      json: _review
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(403)
      _review.foo = oldFoo
      done()

  it 'should modify the document in the DB', (done) ->
    mainDb.get _review._id, (err, review) ->
      should.not.exist(err)
      review.should.eql(_review)
      done()
