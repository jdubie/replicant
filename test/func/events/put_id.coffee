should  = require('should')
async   = require('async')
request = require('request')
kue     = require('kue')

config = require('config')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')
{TestUser, TestSwap, TestEvent} = require('lib/test_models')


describe 'PUT /events/:id', () ->

  guest     = new TestUser('put_events_id_guest')
  host      = new TestUser('put_events_id_host')
  constable = new TestUser('put_events_id_const', roles: ['constable'])
  swap      = new TestSwap('put_events_id_swap', host)
  event     = new TestEvent('put_events_id', [guest], [host], swap)

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel [
        guest.create
        host.create
        constable.create
      ], cb
      swap.create
      event.create
    ], ready

  after (finished) ->
    async.series [
      (cb) -> async.parallel([event.destroy, swap.destroy], cb)
      (cb) -> async.parallel [
        guest.destroy
        host.destroy
        constable.destroy
      ], cb
      (cb) -> config.jobs.client.flushall(cb)    ## move this into parallel
    ], finished


  describe 'normal user', () ->

    it 'should 400 on bad input', (done) ->
      json = event.attributes()
      verifyField = (field, callback) ->
        value = json[field]
        delete json[field]
        opts =
          method: 'PUT'
          url: "http://localhost:3001/events/#{event._id}"
          json: json
          headers: cookie: host.cookie
        request opts, (err, res, body) ->
          should.not.exist(err)
          res.should.have.property('statusCode', 400)
          body.should.have.keys(['error', 'reason'])
          body.reason.should.have.property(field)

          json[field] = value
          callback()
      async.map(['_rev'], verifyField, done)

    it 'should PUT the event', (done) ->
      event.state = EVENT_STATE.confirmed
      opts =
        method: 'PUT'
        url: "http://localhost:3001/events/#{event._id}"
        json: event.attributes()
        headers: cookie: host.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        body.should.have.keys(['_rev', 'mtime'])
        for key, val of body
          event[key] = val
        done()

    it 'should reflect the change in all users DBs (+ drunk_tank)', (done) ->
      getEvent = (user, callback) ->
        userDb = config.db.user(user._id)
        userDb.get event._id, (err, eventDoc) ->
          should.not.exist(err)
          eventDoc.should.eql(event.attributes())
          callback()
      getConstableEvent = (callback) ->
        db = config.db.constable()
        db.get event._id, (err, eventDoc) ->
          should.not.exist(err)
          eventDoc.should.eql(event.attributes())
          callback()
      async.parallel [
        (cb) -> async.map([guest, host], getEvent, cb)
        getConstableEvent
      ], done

    it 'should queue up emails to be sent to the users', (done) ->
      kue.Job.get 1, (err, res) ->
        console.error err if err?
        res.should.have.property('data')
        res.data.should.have.property('event')
        res.data.should.have.property('userId', host._id)
        res.data.should.have.property('rev')
        done()

  describe 'constable', () ->

    it 'should PUT the event', (done) ->
      event.state = EVENT_STATE.completed
      opts =
        method: 'PUT'
        url: "http://localhost:3001/events/#{event._id}"
        json: event.attributes()
        headers: cookie: constable.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        body.should.have.keys(['_rev', 'mtime'])
        for key, val of body
          event[key] = val
        done()

    it 'should reflect the change in all users DBs (+ drunk_tank)', (done) ->
      getEvent = (user, callback) ->
        userDb = config.db.user(user._id)
        userDb.get event._id, (err, eventDoc) ->
          should.not.exist(err)
          eventDoc.should.eql(event.attributes())
          callback()
      getConstableEvent = (callback) ->
        db = config.db.constable()
        db.get event._id, (err, eventDoc) ->
          should.not.exist(err)
          eventDoc.should.eql(event.attributes())
          callback()
      async.parallel [
        (cb) -> async.map([guest, host], getEvent, cb)
        getConstableEvent
      ], done


    it 'should queue up emails to be sent to the users', (done) ->
      # although nothing should be sent for this one!
      kue.Job.get 2, (err, res) ->
        console.error err if err?
        res.should.have.property('data')
        res.data.should.have.property('event')
        res.data.should.have.property('userId', constable._id)
        res.data.should.have.property('rev')
        done()
