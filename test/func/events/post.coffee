should = require('should')
async = require('async')
util = require('util')
request = require('request')
debug = require('debug')('replicant:/test/func/event/post')

{kueUrl, redis, nanoAdmin, nano, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')


describe 'POST /events', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _guests = ['user2_id']
  _hosts = ['user1_id']
  _members = ['user2_id', 'user1_id']
  _members.push(admin) for admin in ADMINS
  _password = 'pass2'
  _swapId = 'swap1'

  cookie = null
  eventId = 'posteventid'
  ctime = mtime = 12345
  _event =
    _id: eventId
    type: 'event'
    state: EVENT_STATE.requested
    swap_id: _swapId
    ctime: ctime
    mtime: mtime

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')

      ## authenticate user
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        redis.flushall(ready)

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
        (cb) -> async.map(_members, destroyEventUser, cb)
        destroyEventMapper
        (cb) -> redis.flushall(cb)
      ], finished


    it 'should POST without failure', (done) ->
      opts =
        method: 'POST'
        url: "http://localhost:3001/events"
        json: _event
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(201)
        returnedFields = ['_rev', 'mtime', 'ctime', 'guests', 'hosts']
        body.should.have.keys(returnedFields)
        for key, val of body
          _event[key] = val
        done()

    it 'should create an event in the \'mapper\' DB', (done) ->
      mapperDb = nanoAdmin.db.use('mapper')
      mapperDb.get eventId, (err, mapperDoc) ->
        should.not.exist(err)
        mapperDoc.should.have.property('guests')
        mapperDoc.guests.should.eql(_guests)
        mapperDoc.should.have.property('hosts')
        mapperDoc.hosts.should.eql(_hosts)
        done()

    it 'should create an event document for involved users', (done) ->
      delete _event.hosts
      delete _event.guests
      checkEventDoc = (userId, callback) ->
        userDbName = getUserDbName(userId: userId)
        userDb = nanoAdmin.db.use(userDbName)
        userDb.get eventId, (err, eventDoc) ->
          should.not.exist(err)
          eventDoc.should.eql(_event)
          callback()
      async.map _members, checkEventDoc, (err, res) ->
        should.not.exist(err)
        done()

    it 'should create event.create notification on work queue', (done) ->
      request.get kueUrl + '/job/1', (err, res, body) ->
        body = JSON.parse(body)
        body.should.have.property('type', 'notification.event.create')
        body.should.have.property('data')
        body.data.should.have.keys('title', 'guests', 'hosts', 'event', 'swap')

        ##
        ## todo assert more stuff about these keys...
        ##

        done()
