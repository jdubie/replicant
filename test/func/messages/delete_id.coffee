should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'DELETE /messages/:id', () ->

  ## from the test/toy data
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _members = ['user2', 'user1']
  _allUsers = (user for user in _members)
  _allUsers.push(user) for user in ADMINS

  _message =
    _id: 'deletemessageid'
    type: 'message'
    message: 'Hey bro'
    event_id: 'deletemessageeventid'
    author: _userId

  mainDb = nanoAdmin.db.use('lifeswap')
  mapperDb = nanoAdmin.db.use('mapper')

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


    it 'should respond with 403 to DELETE /messages/:id', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/messages/#{_message._id}"
        json: _message
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(403)
        done()

    it 'should not delete message for any involved users', (done) ->
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
