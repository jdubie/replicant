should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'PUT /messages/:id', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  cookie = null
  _members = ['user2_id', 'user1_id']
  _allUsers = (user for user in _members)
  _allUsers.push(user) for user in ADMINS
  _ctime = _mtime = 12345

  _message =
    _id: 'putmessageid'
    type: 'message'
    name: _username
    user_id: _userId
    event_id: 'putmessageeventid'
    message: 'Hey bro'
    ctime: _ctime
    mtime: _mtime

  mainDb = nanoAdmin.db.use('lifeswap')
  mapperDb = nanoAdmin.db.use('mapper')

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
      ## put mapping into mapper db
      insertMapping = (cb) ->
        mapperDoc =
          _id: _message.event_id
          users: _members
        mapperDb.insert(mapperDoc, mapperDoc._id, cb)
      ## put message into user DBs
      insertMessage = (userId, cb) ->
        userDb = nanoAdmin.db.use(getUserDbName({userId}))
        userDb.insert _message, _message._id, (err, res) ->
          if not err then _message._rev = res.rev
          cb()
      ## in parallel
      async.parallel [
        authUser
        insertMapping
        (cb) -> async.map(_allUsers, insertMessage, cb)
      ], ready

    after (finished) ->
      ## destroy message (in all users' DBs)
      destroyEventUser = (userId, cb) ->
        userDb = nanoAdmin.db.use(getUserDbName({userId}))
        #userDb.destroy(_message._id, _message._rev, cb)
        userDb.get _message._id, (err, messageDoc) ->
          if err then cb()
          else userDb.destroy(_message._id, _message._rev, cb)

      ## destroy mapping of event in mapper DB
      destroyEventMapper = (cb) ->
        mapperDb.get _message.event_id, (err, mapperDoc) ->
          should.not.exist(err)
          if err then cb()
          else mapperDb.destroy(_message.event_id, mapperDoc._rev, cb)

      async.parallel [
        (cb) -> async.map(_allUsers, destroyEventUser, cb)
        destroyEventMapper
      ], finished


    it 'should return 403 when not changing read/unread status', (done) ->
      oldMessage = _message.message
      _message.message = 'blaggedy'
      _message.read = false
      opts =
        method: 'PUT'
        url: "http://localhost:3001/messages/#{_message._id}"
        json: _message
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(403)
        _message.message = oldMessage
        delete _message.read
        done()

    it 'should return 201 when marking read', (done) ->
      _message.read = true
      opts =
        method: 'PUT'
        url: "http://localhost:3001/messages/#{_message._id}"
        json: _message
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(201)
        delete _message.read
        done()

    it 'should mark the message as \'read\'', (done) ->
      userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))
      opts =
        key: [_message.event_id, _message._id]
      userDb.view 'userddoc', 'messages', opts, (err, res) ->
        should.not.exist(err)
        res.should.have.property('rows').with.lengthOf(1)
        res.rows[0].should.have.property('value', 0)
        done()

    it 'should return 201 when marking unread', (done) ->
      _message.read = false
      opts =
        method: 'PUT'
        url: "http://localhost:3001/messages/#{_message._id}"
        json: _message
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(201)
        delete _message.read
        done()

    it 'should mark the message as \'unread\'', (done) ->
      userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))
      opts =
        key: [_message.event_id, _message._id]
      userDb.view 'userddoc', 'messages', opts, (err, res) ->
        should.not.exist(err)
        res.should.have.property('rows').with.lengthOf(1)
        res.rows[0].should.have.property('value', 1)
        done()

    it 'should not change message for any involved users', (done) ->
      checkMessageDoc = (userId, callback) ->
        userDbName = getUserDbName({userId})
        userDb = nanoAdmin.db.use(userDbName)
        userDb.get _message._id, (err, messageDoc) ->
          should.not.exist(err)
          messageDoc.should.eql(_message)
          callback()
      async.map _allUsers, checkMessageDoc, (err, res) ->
        should.not.exist(err)
        done()
