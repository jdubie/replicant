should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')


describe 'DELETE /events/:id', () ->

  ## simple test - for now should just 403 (forbidden)
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _event =
    _id: 'eventid'
    type: 'event'
    state: EVENT_STATE.requested
    swap_id: 'swap1'

  mainDb = nanoAdmin.db.use('lifeswap')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert event
    insertEvent = (cb) ->
      userDb.insert _event, _event._id, (err, res) ->
        _event._rev = res.rev
        cb()

    async.parallel [
      authUser
      insertEvent
    ], ready


  after (finished) ->
    ## destroy event
    userDb.destroy(_event._id, _event._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/swaps/#{_userId}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'event\' type entry in user db', (done) ->
    userDb.get _event._id, (err, event) ->
      should.not.exist(err)
      event.should.eql(_event)
      done()
