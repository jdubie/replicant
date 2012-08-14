should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl} = require('config')
{getUserDbName} = require('lib/helpers')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')


describe 'POST /events', () ->

  ## from the test/toy data
  _userId = 'user2'
  _members = ['user2', 'user1']
  _password = 'pass2'
  _swapId = 'swap1'

  cookie = null
  eventId = null
  _eventDoc =
    _id: null       # filled in later
    type: 'event'
    state: EVENT_STATE.requested
    swap_id: _swapId

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')

      ## authenticate user
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        ready()


    after (finished) ->
      ## destroy event (in both user's dbs)
      destroyEventUser = (userId, callback) ->
        userDbName = getUserDbName(userId: userId)
        userDb = nanoAdmin.db.use(userDbName)
        userDb.get eventId, (err, eventDoc) ->
          should.not.exist(err)
          userDb.destroy(eventId, eventDoc._rev, callback)

      destroyEventMapper = (callback) ->
        mapperDb = nanoAdmin.db.use('mapper')
        mapperDb.get eventId, (err, mapperDoc) ->
          should.not.exist(err)
          mapperDb.destroy(eventId, mapperDoc._rev, callback)

      async.parallel [
        (cb) -> async.map(['user1', 'user2'], destroyEventUser, cb)
        destroyEventMapper
      ], finished


    it 'should pass back the eventId, users, ok', (done) ->
      opts =
        method: 'POST'
        url: "http://localhost:3001/events"
        json: swapId: _swapId
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(201)
        body.users.should.eql(['user2', 'user1'])
        body.should.have.property('eventId')
        eventId = body.eventId
        _eventDoc._id = eventId
        done()

    it 'should create an event in the \'mapper\' DB', (done) ->
      mapperDb = nanoAdmin.db.use('mapper')
      mapperDb.get eventId, (err, mapperDoc) ->
        should.not.exist(err)
        mapperDoc.should.have.property('users')
        done()

    it 'should create an event document for involved users', (done) ->
      checkEventDoc = (userId, callback) ->
        userDbName = getUserDbName(userId: userId)
        userDb = nanoAdmin.db.use(userDbName)
        userDb.get eventId, (err, eventDoc) ->
          should.not.exist(err)
          _eventDoc._rev = eventDoc._rev
          eventDoc.should.eql(_eventDoc)
          callback()
      async.map _members, checkEventDoc, (err, res) ->
        should.not.exist(err)
        done()
