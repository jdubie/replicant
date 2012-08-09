should = require('should')
async = require('async')
util = require('util')
request = require('request')
{nano} = require('../../config')
{createUser} = require('../../lib/replicant')

{getUserDbName} = require('../../../lifeswap/shared/helpers')

describe 'POST /user', () ->

  _userId = 'newuser'
  _password = 'sekr1t'
  app = null
  cookie = null

  ###
    Make sure that user's db doesn't exist
  ###
  before (ready) ->
    # start webserver
    app = require('../../app')
    insertUser = (callback) ->
      usersDb = nano.db.use('_users')
      userDoc =
        _id: "org.couchdb.user:#{_userId}"
        type: 'user'
        name: _userId
        password: _password
        roles: []
      usersDb.insert userDoc, (err, res) ->
        should.not.exist(err)
        callback()
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    async.series([insertUser, authUser], ready)

  afterEach (finished) ->
    nano.db.list (err, res) ->
      userDbName = getUserDbName({userId: _userId})
      if userDbName in res
        nano.db.destroy(userDbName,finished)
      else finished()

  after (finished) ->
    destroyUser = (callback) ->
      usersDb = nano.db.use('_users')
      couchUser = "org.couchdb.user:#{_userId}"
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        usersDb.destroy(couchUser, userDoc._rev, callback)
    destroyLifeswapUser = (callback) ->
      db = nano.db.use('lifeswap')
      db.get _userId, (err, userDoc) ->
        if err
          callback()
        else
          db.destroy(_userId, userDoc._rev, callback)
    async.parallel([destroyUser, destroyLifeswapUser], finished)


  it 'should 403 when user is unauthenticated', (done) ->
    request.post 'http://localhost:3001/users', (err, res, body) ->
      should.not.exist(err)
      JSON.parse(body).should.have.property('status', 403)
      res.statusCode.should.equal(403)

      # assert user database was not created
      nano.db.list (err, res) ->
        res.should.not.include(_userId)
        done()

  it 'should create user data base if they are authenticated', (done) ->
    opts =
      url: 'http://localhost:3001/users'
      headers: cookie: cookie
    request.post opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.equal(201)
      res.body = JSON.parse(res.body)
      res.body.should.have.property('ok', true)

      # assert user database was created
      nano.db.list (err, res) ->
        userDbName = getUserDbName({userId: _userId})
        res.should.include(userDbName)
        done()

  # @todo be able to start/stop couch from tests
  #it 'should 500 when it fails to create db', (done) ->

