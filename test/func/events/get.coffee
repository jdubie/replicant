should = require('should')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestSwap, TestEvent} = require('lib/test_models')


describe ' GET /events', () ->

  user1  = new TestUser('get_events_user2')
  user2  = new TestUser('get_events_user1')
  swap1  = new TestSwap('get_events_swap1', user1)
  event1 = new TestEvent('get_events1', [user2], [user1], swap1)
  swap2  = new TestSwap('get_events_swap2', user2)
  event2 = new TestEvent('get_events2', [user1], [user2], swap2)

  userDb = nanoAdmin.db.use(getUserDbName(userId: user1._id))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## create users, swaps, and events
    async.series [
      (cb) -> async.parallel([user1.create, user2.create], cb)
      (cb) -> async.parallel([swap1.create, swap2.create], cb)
      (cb) -> async.parallel([event1.create, event2.create], cb)
    ], ready

  after (finished) ->
    ## destroy events and swaps, then users
    async.series [
      (cb) -> async.parallel [
        event1.destroy
        event2.destroy
        swap1.destroy
        swap2.destroy
        ], cb
      (cb) -> async.parallel([user1.destroy, user2.destroy], cb)
    ], finished


  it 'should GET all events', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/events"
      json: true
      headers: cookie: user1.cookie
    request opts, (err, res, events) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      ## TODO: should probably make sure these are correct!
      #         but for now just delete them
      eventsNano = [event1.attributes(), event2.attributes()]
      for _event in events
        _event.should.have.property('hosts')
        delete _event.hosts
        _event.should.have.property('guests')
        delete _event.guests
      events.should.eql(eventsNano)
      done()
