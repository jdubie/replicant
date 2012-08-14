should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin, dbUrl} = require('config')

getUserDbName = ({userId}) -> return "users_#{userId}"


describe 'DELETE /users/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  _userId = 'deleteuser'
  _password = 'sekr1t'
  _userDoc =
    _id: _userId
    type: 'user'
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  userDbName = getUserDbName(userId: _userId)

  before (ready) ->
    ## start webserver
    app = require('../../../app')

    ## insert user
    insertUser = (callback) ->
      async.parallel [
        (cb) ->
          userDoc =
            _id: "org.couchdb.user:#{_userId}"
            type: 'user'
            name: _userId
            password: _password
            roles: []
          usersDb.insert userDoc, (err, res) ->
            should.not.exist(err)
            cb()
        (cb) ->
          mainDb.insert _userDoc, _userId, (err, res) ->
            should.not.exist(err)
            _userDoc._rev = res.rev
            cb()
        (cb) ->
          nanoAdmin.db.create userDbName, (err, res) ->
            should.not.exist(err)
            cb()
      ], callback

    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()

    async.series([insertUser, authUser], ready)


  after (finished) ->
    destroyUser = (callback) ->
      couchUser = "org.couchdb.user:#{_userId}"
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        usersDb.destroy(couchUser, userDoc._rev, callback)
    destroyLifeswapUser = (callback) ->
      mainDb.get _userId, (err, userDoc) ->
        should.not.exist(err)
        mainDb.destroy(_userId, userDoc._rev, callback)
    destroyUserDb = (callback) ->
      nanoAdmin.db.list (err, dbs) ->
        dbs.should.include(userDbName)
        nanoAdmin.db.destroy userDbName, (err, res) ->
          should.not.exist(err)
          finished()

    async.parallel [
      destroyUser
      destroyLifeswapUser
      destroyUserDb
    ], finished


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/users/#{_userId}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete _users entry', (done) ->
    couchUser = "org.couchdb.user:#{_userId}"
    usersDb.get couchUser, (err, userDoc) ->
      should.not.exist(err)
      userDoc.should.have.property('_id', couchUser)
      done()


  it 'should not delete \'user\' type entry in lifeswap db', (done) ->
    mainDb.get _userId, (err, userDoc) ->
      should.not.exist(err)
      userDoc.should.eql(_userDoc)
      done()
