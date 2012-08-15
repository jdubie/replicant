should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')


describe 'GET /events', () ->

  ## from the test/toy data
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _events = [
    {
      _id: 'eventid1'
      type: 'event'
      state: EVENT_STATE.requested
      swap_id: 'swap1'
    }
    {
      _id: 'eventid2'
      type: 'event'
      state: EVENT_STATE.requested
      swap_id: 'swap1'
    }
  ]

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')
      ## authenticate user
      authUser = (cb) ->
        nano.auth _userId, _password, (err, body, headers) ->
          should.not.exist(err)
          should.exist(headers and headers['set-cookie'])
          cookie = headers['set-cookie'][0]
          cb()
      ## insert event
      insertEvent = (event, cb) ->
        userDb.insert event, event._id, (err, res) ->
          event._rev = res.rev
          cb()
      insertEvents = (cb) -> async.map(_events, insertEvent, cb)
      ## in parallel
      async.parallel [
        authUser
        insertEvents
      ], (err, res) ->
        ready()


    after (finished) ->
      ## destroy events
      destroyEvent = (event, callback) ->
        userDb.destroy(event._id, event._rev, callback)
      ## in parallel
      async.map(_events, destroyEvent, finished)


    it 'should GET all events', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3000/events"
        json: true
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        body.should.eql(_events)
        done()
