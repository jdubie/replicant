should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')


describe 'PUT /events/:id', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _hosts = ['user1_id']
  _guests = ['user2_id']
  _allUsers = (user for user in _hosts)
  _allUsers.push(user) for user in _guests
  _allUsers.push(user) for user in ADMINS
  cookie = null
  ctime = mtime = 12345
  _event =
    _id: 'puteventid'
    type: 'event'
    state: EVENT_STATE.requested
    swap_id: 'swap1'
    ctime: ctime
    mtime: mtime

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user (host of swap)
    authUser = (cb) ->
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        cb()
    ## insert event
    insertEvent = (userId, cb) ->
      userDb = nanoAdmin.db.use(getUserDbName({userId}))
      userDb.insert _event, _event._id, (err, res) ->
        _event._rev = res.rev
        cb()
    insertEvents = (cb) -> async.map(_allUsers, insertEvent, cb)
    ##
    insertIntoMapper = (cb) ->
      mapperDb = nanoAdmin.db.use('mapper')
      mapperDoc =
        _id: _event._id
        guests: _guests
        hosts: _hosts
      mapperDb.insert(mapperDoc, _event._id, cb)
    ## in parallel
    async.parallel [
      authUser
      insertEvents
      insertIntoMapper
    ], ready


  after (finished) ->
    ## destroy event
    destroyEvent = (userId, cb) ->
      userDb = nanoAdmin.db.use(getUserDbName({userId}))
      userDb.destroy(_event._id, _event._rev, cb)
    ## destroy mapper document of event
    destroyMapperEvent = (cb) ->
      mapperDb = nanoAdmin.db.use('mapper')
      mapperDb.get _event._id, (err, mapperDoc) ->
        mapperDb.destroy(mapperDoc._id, mapperDoc._rev, cb)
    ## in parallel
    async.parallel [
      (cb) -> async.map(_allUsers, destroyEvent, cb)
      destroyMapperEvent
    ], finished

  it 'should PUT the event', (done) ->
    _event.state = EVENT_STATE.confirmed
    opts =
      method: 'PUT'
      url: "http://localhost:3001/events/#{_event._id}"
      json: _event
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        _event[key] = val
      done()

  it 'should reflect the change in all users DBs', (done) ->
    getEvent = (userId, cb) ->
      userDb = nanoAdmin.db.use(getUserDbName({userId}))
      userDb.get _event._id, (err, event) ->
        should.not.exist(err)
        event.should.eql(_event)
        cb()
    async.map(_allUsers, getEvent, done)
