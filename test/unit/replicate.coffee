util = require('util')
should = require('should')
async = require('async')
nano = require('nano')('http://tester:tester@localhost:5985')
{replicate} = require('../../lib/replicant')

describe 'POST /swapEvent', () ->

  # @note depends on lifeswap/scripts/instances/toy_data.coffee
  user1 = 'user1'
  user2 = 'user2'
  swapEventID = 'swapEventID'
  mapperDB = 'mapper'

  results = null # to be assigned in before
  error = null # to be assigned in before
  msgID = null

  ensureUser1DB = (callback) ->
    nano.db.list (err,dbs) ->
      if not (user1 in dbs)
        nano.db.create(user1,callback)
      else callback()

  ensureUser2DB = (callback) ->
    nano.db.list (err,dbs) ->
      if not (user2 in dbs)
        nano.db.create(user2,callback)
      else callback()

  ensureMapperPresent = (callback) ->
    nano.db.list (err,dbs) ->
      if not (mapperDB in dbs)
        nano.db.create(mapperDB, callback)
      else callback()

  ensureSwapEventExists = (callback) ->
    db = nano.db.use(mapperDB)
    db.get swapEventID, (err, swapEventDoc) ->
      if err
        swapEventDoc =
          _id: swapEventID
          users: [user1, user2]
        db.insert swapEventDoc, swapEventID, callback
      else
        callback()

  before (ready) ->
    async.parallel [
      ensureUser1DB
      ensureUser2DB
      ensureMapperPresent
      ensureSwapEventExists
    ], (err, res) ->
      should.not.exist(err)

      user1db = nano.db.use(user1)
      msgDoc =
        type: 'message'
        swapEventID: swapEventID
        message: 'hey bro'
      user1db.insert msgDoc, (err, res) ->
        should.not.exist(err)
        msgID = res.id
        replicateParams =
          src: user1
          dsts: [user2]
          swapEventID: swapEventID
        replicate replicateParams, (err, res) ->
          error = err
          results = res
          ready()

  after (finished) ->
    destroyUser1DB = (callback) ->
      nano.db.destroy(user1, callback)
    destroyUser2DB = (callback) ->
      nano.db.destroy(user2, callback)
    async.parallel [
      destroyUser1DB
      destroyUser2DB
    ], (err, res) ->
      should.not.exist(err)
      finished()

  it 'should not error', () ->
    should.not.exist(error)

  it 'should return ok', () ->
    results.should.have.length(1)
    results[0].should.have.property('ok', true)

  it 'should replicate the message to the other user', (done) ->
    db = nano.db.use(user2)
    db.get msgID, (err, msgDoc) ->
      should.not.exist(err)
      msgDoc.should.have.property('swapEventID', swapEventID)
      msgDoc.should.have.property('type', 'message')
      done()

  it 'should keep the message in the first user\'s db', (done) ->
    db = nano.db.use(user1)
    db.get msgID, (err, msgDoc) ->
      should.not.exist(err)
      msgDoc.should.have.property('swapEventID', swapEventID)
      msgDoc.should.have.property('type', 'message')
      done()
