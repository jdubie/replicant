should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{getUserDbName, hash} = require('lib/helpers')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')


describe 'GET /events/:id', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _hosts = ['user1_id']
  _guests = [_userId]
  _ctime = _mtime = 12345
  _event =
    _id: 'eventid'
    type: 'event'
    state: EVENT_STATE.requested
    swap_id: 'swap1'
    ctime: _ctime
    mtime: _mtime
  _mapping =
    _id: 'eventid'
    hosts: _hosts
    guests: _guests
  cookie = null


  mainDb = nanoAdmin.db.use('lifeswap')
  mapperDb = nanoAdmin.db.use('mapper')
  usersDb = nanoAdmin.db.use('_users')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))


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
    ## insert event
    insertEvent = (cb) ->
      userDb.insert _event, _event._id, (err, res) ->
        _event._rev = res.rev
        cb()
    ## insert mapper document for event
    insertMapping = (cb) ->
      mapperDb.insert _mapping, _mapping._id, (err, res) ->
        _mapping._rev = res.rev
        cb()
    ## in parallel
    async.parallel [
      authUser
      insertEvent
      insertMapping
    ], (err, res) ->
      ready()


  after (finished) ->
    ## destroy event
    async.parallel [
      (cb) -> userDb.destroy(_event._id, _event._rev, cb)
      (cb) -> mapperDb.destroy(_mapping._id, _mapping._rev, cb)
    ], finished


  it 'should GET the event', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/events/#{_event._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, event) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      event.should.have.property('guests')
      event.guests.should.eql(_guests)
      delete event.guests
      event.should.have.property('hosts')
      event.hosts.should.eql(_hosts)
      delete event.hosts
      event.should.eql(_event)
      done()
