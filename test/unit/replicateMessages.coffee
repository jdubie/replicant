util = require('util')
should = require('should')
async = require('async')
{nano} = require('../../config')
{replicateMessages} = require('../../lib/replicant')

{getUserDbName} = require('../../../lifeswap/shared/helpers')

describe '#replicateMessages', () ->

  msgFilter = (doc, req) ->
    if doc.eventId isnt req.query.eventId
      return false
    else
      return true

  # @note depends on lifeswap/scripts/instances/toy_data.coffee
  user1 = 'user1'
  user2 = 'user2'
  eventId = 'eventid'
  badEventId = 'badeventid'
  mapperDB = 'mapper'
  userDdocName = 'userddoc'

  user1DbName = getUserDbName({userId: user1})
  user2DbName = getUserDbName({userId: user2})

  results = null # to be assigned in before
  error = null # to be assigned in before
  _msgId = null
  _badMsgId = null

  ensureUser1DB = (callback) ->
    nano.db.list (err,dbs) ->
      if not (user1DbName in dbs)
        nano.db.create user1DbName, (err, res) ->
          should.not.exist(err)
          userdb = nano.db.use(user1DbName)
          ddoc =
            _id: "_design/#{userDdocName}"
            filters:
              msgFilter: msgFilter.toString()
          userdb.insert(ddoc, callback)
      else callback()

  ensureUser2DB = (callback) ->
    nano.db.list (err,dbs) ->
      if not (user2DbName in dbs)
        nano.db.create user2DbName, (err, res) ->
          should.not.exist(err)
          # doesn't actually matter for tests as-is
          userdb = nano.db.use(user2DbName)
          ddoc =
            _id: "_design/#{userDdocName}"
            filters:
              msgFilter: msgFilter.toString()
          userdb.insert(ddoc, callback)
      else callback()

  ensureMapperPresent = (callback) ->
    nano.db.list (err,dbs) ->
      if not (mapperDB in dbs)
        nano.db.create(mapperDB, callback)
      else callback()

  ensureSwapEventExists = (callback) ->
    db = nano.db.use(mapperDB)
    db.get eventId, (err, swapEventDoc) ->
      if err
        swapEventDoc =
          _id: eventId
          users: [user1, user2]
        db.insert swapEventDoc, eventId, callback
      else
        callback()

  ensureBadSwapEventExists = (callback) ->
    db = nano.db.use(mapperDB)
    db.get eventId, (err, swapEventDoc) ->
      if err
        swapEventDoc =
          _id: badEventId
          users: [user1, user2]
        db.insert(swapEventDoc, badEventId, callback)
      else
        callback()

  before (ready) ->
    async.parallel [
      ensureUser1DB
      ensureUser2DB
      ensureMapperPresent
      ensureSwapEventExists
      ensureBadSwapEventExists
    ], (err, res) ->
      should.not.exist(err)

      user1db = nano.db.use(user1DbName)
      msgDoc =
          type: 'message'
          eventId: eventId
          message: 'hey bro'
      badMsgDoc =
          type: 'message'
          eventId: badEventId
          message: 'boo brohan'
      user1db.insert msgDoc, (err, res) ->
        should.not.exist(err)
        _msgId = res.id
        user1db.insert badMsgDoc, (err, res) ->
          should.not.exist(err)
          _badMsgId = res.id

          replicateParams =
            src: user1
            dsts: [user2]
            eventId: eventId
          replicateMessages replicateParams, (err, res) ->
            error = err
            results = res
            ready()

  after (finished) ->
    destroyUserMsg = ({userId, msgId}, callback) ->
      userDbName = getUserDbName({userId})
      userdb = nano.db.use(userDbName)
      userdb.get msgId, (err, msgDoc) ->
        should.not.exist(err)
        userdb.destroy msgId, msgDoc._rev, (err, res) ->
          should.not.exist(err)
          callback()
    params = [
      {userId: user1, msgId: _msgId}
      {userId: user1, msgId: _badMsgId}
      {userId: user2, msgId: _msgId}
    ]
    async.map params, destroyUserMsg, (err, res) ->
      should.not.exist(err)
      finished()


  it 'should not error', () ->
    should.not.exist(error)

  it 'should return ok', () ->
    results.should.have.length(1)
    results[0].should.have.property('ok', true)

  it 'should replicate the message to the other user', (done) ->
    db = nano.db.use(user2DbName)
    db.get _msgId, (err, msgDoc) ->
      should.not.exist(err)
      msgDoc.should.have.property('eventId', eventId)
      msgDoc.should.have.property('type', 'message')
      done()

  it 'should not replicate the wrong message', (done) ->
    db = nano.db.use(user2DbName)
    db.get _badMsgId, (err, res) ->
      err.should.have.property('status_code', 404)
      done()

  it 'should keep both messages in the first user\'s db', (done) ->
    db = nano.db.use(user1DbName)
    db.get _msgId, (err, msgDoc) ->
      should.not.exist(err)
      msgDoc.should.have.property('eventId', eventId)
      msgDoc.should.have.property('type', 'message')
      db.get _badMsgId, (err, bMsgDoc) ->
        bMsgDoc.should.have.property('eventId', badEventId)
        bMsgDoc.should.have.property('type', 'message')
        done()