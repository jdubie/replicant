should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'POST /messages', () ->

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
    _id: 'postmessage'
    type: 'message'
    name: _username
    user_id: _userId
    event_id: 'postmessageeventid'
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
      async.parallel [
        authUser
        insertMapping
      ], ready

    after (finished) ->
      ## destroy message (in both user's DBs)
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

      ## destroy read document
      destroyReadDocs = (cb) ->
        userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))
        destroyReadDoc = (row, _cb) ->
          doc = row.doc
          if doc.type isnt 'read' then _cb()
          else userDb.destroy(doc._id, doc._rev, _cb)
        opts =
          reduce: false
          include_docs: true
        userDb.view 'userddoc', 'messages', opts, (err, res) ->
          if err then cb()
          else async.map(res.rows, destroyReadDoc, cb)

      async.parallel [
        (cb) -> async.map(_allUsers, destroyEventUser, cb)
        destroyEventMapper
        destroyReadDocs
      ], finished


    it 'should POST without failure', (done) ->
      opts =
        method: 'POST'
        url: "http://localhost:3001/messages"
        json: _message
        headers: cookie: cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(201)
        body.should.have.keys(['_rev', 'ctime', 'mtime'])
        for key, val of body
          _message[key] = val
        done()

    it 'should replicate the message to all involved users', (done) ->
      checkMessageDoc = (userId, cb) ->
        userDbName = getUserDbName({userId})
        userDb = nanoAdmin.db.use(userDbName)
        userDb.get _message._id, (err, messageDoc) ->
          should.not.exist(err)
          messageDoc.should.eql(_message)
          cb()
      async.map(_allUsers, checkMessageDoc, done)

    it 'should mark the message as read for the author', (done) ->
      checkMessageReadStatus = (userId, cb) ->
        userDbName = getUserDbName({userId})
        userDb = nanoAdmin.db.use(userDbName)
        opts = key: [_message.event_id, _message._id]
        userDb.view 'userddoc', 'messages', opts, (err, res) ->
          should.not.exist(err)
          res.should.have.property('rows').with.lengthOf(1)
          if userId is _userId
            res.rows[0].should.have.property('value', 0)
          else
            res.rows[0].should.have.property('value', 1)
          cb()
      async.map(_allUsers, checkMessageReadStatus, done)
