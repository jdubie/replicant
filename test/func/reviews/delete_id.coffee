should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin, dbUrl} = require('config')


describe 'DELETE /reviews/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  _userId = 'deletereviewsuser'
  _password = 'sekr1t'
  ctime = mtime = 12345
  _reviewDoc =
    _id: 'deletereview'
    type: 'review'
    host: _userId
    ctime: ctime
    mtime: mtime
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')

  before (ready) ->
    ## start webserver
    app = require('../../../app')

    ## insert user
    insertUser = (callback) ->
      userDoc =
        _id: "org.couchdb.user:#{_userId}"
        type: 'user'
        name: _userId
        password: _password
        roles: []
      usersDb.insert userDoc, (err, res) ->
        should.not.exist(err)
        callback()

    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()

    ## insert review
    insertReview = (callback) ->
      mainDb.insert _reviewDoc, (err, res) ->
        should.not.exist(err)
        _reviewDoc._rev = res.rev
        callback()

    async.series [
      insertUser
      authUser
      insertReview
    ], ready


  after (finished) ->
    ## destroy user
    destroyUser = (callback) ->
      couchUser = "org.couchdb.user:#{_userId}"
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        usersDb.destroy(couchUser, userDoc._rev, callback)
    ## destroy review
    destroyReview = (callback) ->
      mainDb.get _reviewDoc._id, (err, reviewDoc) ->
        should.not.exist(err)
        mainDb.destroy(reviewDoc._id, reviewDoc._rev, callback)
    ## in parallel
    async.parallel([destroyUser, destroyReview], finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/reviews/#{_reviewDoc._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'review\' type entry in lifeswap db', (done) ->
    mainDb.get _reviewDoc._id, (err, reviewDoc) ->
      should.not.exist(err)
      reviewDoc.should.eql(_reviewDoc)
      done()
