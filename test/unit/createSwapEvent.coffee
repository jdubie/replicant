util = require('util')
should = require('should')
async = require('async')
nano = require('nano')('http://tester:tester@localhost:5985')
{createSwapEvent} = require('../../lib/replicant')

describe '#createSwapEvent', () ->

  # @note depends on lifeswap/scripts/instances/toy_data.coffee

  swapId = 'swap1' # owns swap 1
  userId = 'user2'

  result = null # to be assigned in before
  error = null # to be assigned in before

  ensureMapperPresent = (callback) ->
    nano.db.list (err,dbs) ->
      if not ('mapper' in dbs)
        nano.db.create('mapper',callback)
      else callback()

  ensureSwapExists = (callback) ->
    db = nano.db.use('lifeswap')
    db.get 'swap1', (err, res) ->
      if res? then callback()
      else if err.status_code is 404 # create them if they don't exist
        doc =
          _id: 'swap1'
          type: 'swap'
          host: 'user1'
          status: 'approved'
        db.insert doc, doc._id, callback
      else callback(err)

  ensureSwapHostExists = (callback) ->
    db = nano.db.use('lifeswap')
    db.get 'user1', (err, res) ->
      if res? then callback()
      else if err.status_code is 404 # create them if they don't exist
        doc =
          _id: 'user1'
          type: 'user'
        db.insert doc, doc._id, callback
      else callback(err)

  before (ready) ->
    async.parallel [
      ensureMapperPresent
      ensureSwapExists
      ensureSwapHostExists
    ], (err, res) ->
      should.not.exist(err)

      createSwapEvent {swapId, userId}, (err,res) ->
        error = err
        result = res
        ready()

  it 'should not error', () ->
    should.not.exist(error)

  it 'should should return ok', () ->
    result.should.have.property('ok', true)

  it 'should return a swapEventId', () ->
    result.should.have.property('swapEventId')

  it 'should return a list of users', () ->
    result.users.should.eql(['user1', 'user2'])

  it 'should create that corresponding mapping', (done) ->
    db = nano.db.use('mapper')
    db.get result.swapEventId, (err,doc) ->
      should.not.exist(err)
      doc.should.have.property('_id', result.swapEventId)
      doc.should.have.property('users')
      doc.users.should.eql(['user1', 'user2'])
      done()
    
  # @todo assert existence of user data document
  # @todo 
