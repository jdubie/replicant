should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')


describe 'GET /events', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _eventsNano = []
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')
      ## authenticate user
      authUser = (cb) ->
        nano.auth _username, _password, (err, body, headers) ->
          should.not.exist(err)
          should.exist(headers and headers['set-cookie'])
          cookie = headers['set-cookie'][0]
          cb()
      ## get events
      getEvents = (cb) ->
        opts =
          key: 'event'
          include_docs: true
        userDb.view 'userddoc', 'docs_by_type', opts, (err, res) ->
          _eventsNano = (row.doc for row in res.rows)
          cb()
      insertEvents = (cb) -> async.map(_events, insertEvent, cb)
      ## in parallel
      async.parallel [
        authUser
        getEvents
      ], (err, res) ->
        ready()


    after (finished) ->
      ## destroy events
      destroyEvent = (event, callback) ->
        userDb.destroy(event._id, event._rev, callback)
      ## in parallel
      async.map(_eventsNano, destroyEvent, finished)


    it 'should GET all events', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/events"
        json: true
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        body.should.eql(_eventsNano)
        done()
