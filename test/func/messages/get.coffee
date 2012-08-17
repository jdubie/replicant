should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'GET /messages', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  cookie = null
  ctime = mtime = 12345
  _messages = [
    {
      _id: "getmessages1"
      type: "message"
      name: _username
      user_id: "user2_id"
      event_id: "getmessagesevent"
      message: "bro"
      ctime: ctime
      mtime: mtime
    }
    {
      _id: "getmessages2"
      type: "message"
      name: hash('user1@test.com')
      user_id: "user1_id"
      event_id: "getmessagesevent"
      message: "booger"
      ctime: ctime
      mtime: mtime
    }
  ]
  _readDoc =
    _id: "getmessagesreaddoc"
    type: "read"
    message_id: "getmessages1"
    event_id: _messages[0].event_id
    ctime: ctime

  mainDb = nanoAdmin.db.use('lifeswap')

  ## these could be general functions (helpers?)
  insertDocUser = (userId, doc, cb) ->
    userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))
    userDb.insert doc, doc._id, (err, res) ->
      if not err then doc._rev = res.rev
      cb()
  destroyDocUser = (userId, doc, cb) ->
    userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))
    userDb.destroy(doc._id, doc._rev, cb)

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
    insertMessage = (msg, cb) -> insertDocUser(_userId, msg, cb)
    ## in parallel
    async.parallel [
      authUser
      ## put messages into user's DB
      (cb) -> async.map(_messages, insertMessage, cb)
      ## put read doc into user DB
      (cb) -> insertDocUser(_userId, _readDoc, cb)
    ], ready

  after (finished) ->
    destroyMessage = (msg, cb) -> destroyDocUser(_userId, msg, cb)
    async.parallel [
      ## destroy all messages in user's DB
      (cb) -> async.map(_messages, destroyMessage, cb)
      ## destroy read document
      (cb) -> destroyDocUser(_userId, _readDoc, cb)
    ], finished


  it 'should GET all messages w/ correct read status', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages"
      json: true
      headers: cookie: cookie
    request opts, (err, res, messages) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      _messages[0].read = true
      _messages[1].read = false
      messages.should.eql(_messages)
      done()
