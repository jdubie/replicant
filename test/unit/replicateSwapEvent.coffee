util = require('util')
should = require('should')
async = require('async')
nano = require('nano')('http://tester:tester@localhost:5985')
{replicate} = require('../../lib/replicant')

describe '#replicate', () ->

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

  results = null # to be assigned in before
  error = null # to be assigned in before
  _msgId = null
  badMsgID = null

  ensureUser1DB = (callback) ->
    nano.db.list (err,dbs) ->
      if not (user1 in dbs)
        nano.db.create user1, (err, res) ->
          should.not.exist(err)
          userdb = nano.db.use(user1)
          ddoc =
            _id: "_design/#{user1}"
            filters:
              msgFilter: msgFilter.toString()
          userdb.insert(ddoc, callback)
      else callback()

  ensureUser2DB = (callback) ->
    nano.db.list (err,dbs) ->
      if not (user2 in dbs)
        nano.db.create user2, (err, res) ->
          should.not.exist(err)
          # doesn't actually matter for tests as-is
          userdb = nano.db.use(user2)
          ddoc =
            _id: "_design/#{user2}"
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
        db.insert swapEventDoc, badEventId, callback
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

      user1db = nano.db.use(user1)
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
          badMsgID = res.id

          replicateParams =
            src: user1
            dsts: [user2]
            eventId: eventId
          replicate replicateParams, (err, res) ->
            error = err
            results = res
            ready()

  after (finished) ->
    destroyUserMsg = (userId, callback) ->
      userdb = nano.db.use(userId)
      userdb.get _msgId, (err, msgDoc) ->
        should.not.exist(err)
        userdb.destroy _msgId, msgDoc._rev, (err, res) ->
          should.not.exist(err)
          callback()
    async.map [user1, user2], destroyUserMsg, (err, res) ->
      should.not.exist(err)
      finished()


  it 'should not error', () ->
    should.not.exist(error)

  it 'should return ok', () ->
    results.should.have.length(1)
    results[0].should.have.property('ok', true)

  it 'should replicate the message to the other user', (done) ->
    db = nano.db.use(user2)
    db.get _msgId, (err, msgDoc) ->
      should.not.exist(err)
      msgDoc.should.have.property('eventId', eventId)
      msgDoc.should.have.property('type', 'message')
      done()

  it 'should not replicate the wrong message', (done) ->
    db = nano.db.use(user2)
    db.get badMsgID, (err, res) ->
      err.should.have.property('status_code', 404)
      done()

  it 'should keep both messages in the first user\'s db', (done) ->
    db = nano.db.use(user1)
    db.get _msgId, (err, msgDoc) ->
      should.not.exist(err)
      msgDoc.should.have.property('eventId', eventId)
      msgDoc.should.have.property('type', 'message')
      db.get badMsgID, (err, bMsgDoc) ->
        bMsgDoc.should.have.property('eventId', badEventId)
        bMsgDoc.should.have.property('type', 'message')
        done()
