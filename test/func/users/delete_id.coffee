should = require('should')
async = require('async')
util = require('util')
request = require('request')

config = require('config')
h = require('lib/helpers')


describe 'DELETE /users/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  user =
    _id: 'deleteuser'
    type: 'user'
    ctime: 12345
    mtime: 12345
    foo: 'delete bar'
    email_address: 'deleteuser@thelifeswap.com'
    password: 'deletepass'
    # name is computed inside create user

  #_adminName = h.hash('tester@test.com')
  #_adminPass = 'tester'
  #_adminCookie = null

  # incoming data from before
  _userRev    = null
  _userCookie = null
  couchUser   = null

  mainDb = config.nanoAdmin.db.use('lifeswap')
  usersDb = config.nanoAdmin.db.use('_users')
  userDbName = h.getUserDbName(userId: user._id)

  before (ready) ->
    ## start webserver
    app = require('app')

    h.createUser {user: user, roles: []}, (err, res) ->
      return ready(err) if err
      {couchUser, _rev, cookie} = res
      _userRev = _rev
      _userCookie = cookie
      ready()


  after (finished) ->
    h.destroyUser(user, finished)

  describe 'regular user', () ->
    it 'should return a 403 (forbidden)', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/users/#{user._id}"
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
      mainDb.get user._id, (err, userDoc) ->
        should.not.exist(err)
        userDoc.should.eql(user)
        done()

    it 'should not delete user DB', (done) ->
      config.nanoAdmin.db.list (err, dbs) ->
        should.not.exist(err)
        dbs.should.include(userDbName)
        done()

        #  describe 'constable', () ->
        #
        #    it 'should return a 200 (OK)', (done) ->
        #      opts =
        #        method: 'DELETE'
        #        url: "http://localhost:3001/users/#{user._id}"
        #        json: true
        #        headers: cookie: _adminCookie
        #      request opts, (err, res, body) ->
        #        should.not.exist(err)
        #        res.should.have.property('statusCode', 200)
        #        done()
        #
        #    it 'should delete the _users entry', (done) ->
        #      usersDb.get couchUser, (err, userDoc) ->
        #        should.exist(err)
        #        err.should.have.property('status_code', 404)
        #        done()
        #
        #    it 'should delete the \'user\' type entry in lifeswap db', (done) ->
        #      mainDb.get user._id, (err, userDoc) ->
        #        should.exist(err)
        #        err.should.have.property('status_code', 404)
        #        done()
        #
        #    it 'should delete the user DB', (done) ->
        #      config.nanoAdmin.db.list (err, dbs) ->
        #        dbs.should.not.include(userDbName)
        #        done()
