should = require('should')
async = require('async')
util = require('util')
request = require('request')
{TestUser} = require('lib/test_models')

config = require('config')
h = require('lib/helpers')


describe 'zzzz DELETE /users/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  user = new TestUser('deleteuser')

  #_adminName = h.hash('tester@test.com')
  #_adminPass = 'tester'
  #_adminCookie = null

  mainDb = config.nanoAdmin.db.use('lifeswap')
  usersDb = config.nanoAdmin.db.use('_users')
  userDbName = h.getUserDbName(userId: user._id)

  before (ready) ->
    ## start webserver
    app = require('app')

    user.create(ready)


  after (finished) ->
    user.destroy(finished)

  describe 'regular user', () ->
    it 'should return a 403 (forbidden)', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/users/#{user._id}"
        json: true
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 403)
        done()

    it 'should not delete _users entry', (done) ->
      usersDb.get user.couchUser, (err, userDoc) ->
        should.not.exist(err)
        userDoc.should.have.property('_id', user.couchUser)
        done()

    it 'should not delete \'user\' type entry in lifeswap db', (done) ->
      mainDb.get user._id, (err, userDoc) ->
        should.not.exist(err)
        userDoc.should.eql(user.attributes())
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
        #      usersDb.get user.couchUser, (err, userDoc) ->
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
