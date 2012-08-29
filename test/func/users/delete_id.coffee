should = require('should')
async = require('async')
util = require('util')
request = require('request')

config = require('config')
h = require('lib/helpers')


describe 'DELETE /users/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  _username = h.hash('deleteuser@test.com')
  _password = 'deletepass'
  _userId = 'deleteuser'
  _ctime = _mtime = 12345
  _userDoc =
    _id: _userId
    type: 'user'
    name: _username
    ctime: _ctime
    mtime: _mtime
    foo: 'delete bar'
  _userCookie = null
  couchUser = "org.couchdb.user:#{_username}"

  _adminName = h.hash('tester@test.com')
  _adminPass = 'tester'
  _adminCookie = null

  mainDb = config.nanoAdmin.db.use('lifeswap')
  usersDb = config.nanoAdmin.db.use('_users')
  userDbName = h.getUserDbName(userId: _userId)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user
    insertUser = (callback) ->
      async.parallel [
        (cb) ->
          userDoc =
            _id: couchUser
            type: 'user'
            name: _username
            password: _password
            roles: []
            user_id: _userId
          usersDb.insert userDoc, (err, res) ->
            should.not.exist(err)
            cb()
        (cb) ->
          mainDb.insert _userDoc, _userId, (err, res) ->
            should.not.exist(err)
            _userDoc._rev = res.rev
            cb()
        (cb) ->
          config.nanoAdmin.db.create userDbName, (err, res) ->
            should.not.exist(err)
            cb()
      ], callback

    ## authenticate user
    authUsers = (callback) ->
      async.parallel [
        (cb) ->
          config.nano.auth _username, _password, (err, body, hdr) ->
            should.not.exist(err)
            should.exist(hdr and hdr['set-cookie'])
            _userCookie = hdr['set-cookie'][0]
            cb()
        (cb) ->
          config.nano.auth _adminName, _adminPass, (err, body, hdr) ->
            should.not.exist(err)
            should.exist(hdr and hdr['set-cookie'])
            _adminCookie = hdr['set-cookie'][0]
            cb()
      ], callback

    async.series([insertUser, authUsers], ready)


  after (finished) ->
    destroyUser = (callback) ->
      usersDb.get couchUser, (err, userDoc) ->
        return callback() if err?   # should error
        usersDb.destroy(couchUser, userDoc._rev, callback)
    destroyLifeswapUser = (callback) ->
      mainDb.get _userId, (err, userDoc) ->
        return callback() if err?   # should error
        mainDb.destroy(_userId, userDoc._rev, callback)
    destroyUserDb = (callback) ->
      config.nanoAdmin.db.list (err, dbs) ->
        return callback() if not (userDbName in dbs)  # should callback
        config.nanoAdmin.db.destroy userDbName, (err, res) ->
          should.not.exist(err)
          callback()

    async.parallel [
      destroyUser
      destroyLifeswapUser
      destroyUserDb
    ], finished


  describe 'regular user', () ->
    it 'should return a 403 (forbidden)', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/users/#{_userId}"
        json: true
        headers: cookie: _userCookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 403)
        done()


    it 'should not delete _users entry', (done) ->
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        userDoc.should.have.property('_id', couchUser)
        done()


    it 'should not delete \'user\' type entry in lifeswap db', (done) ->
      mainDb.get _userId, (err, userDoc) ->
        should.not.exist(err)
        userDoc.should.eql(_userDoc)
        done()

    it 'should not delete user DB', (done) ->
      config.nanoAdmin.db.list (err, dbs) ->
        should.not.exist(err)
        dbs.should.include(userDbName)
        done()

  describe 'constable', () ->

    it 'should return a 200 (OK)', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/users/#{_userId}"
        json: true
        headers: cookie: _adminCookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        done()

    it 'should delete the _users entry', (done) ->
      usersDb.get couchUser, (err, userDoc) ->
        should.exist(err)
        err.should.have.property('status_code', 404)
        done()

    it 'should delete the \'user\' type entry in lifeswap db', (done) ->
      mainDb.get _userId, (err, userDoc) ->
        should.exist(err)
        err.should.have.property('status_code', 404)
        done()

    it 'should delete the user DB', (done) ->
      config.nanoAdmin.db.list (err, dbs) ->
        dbs.should.not.include(userDbName)
        done()
