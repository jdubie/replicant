should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

{TestUser, TestSwap, TestEvent} = require('lib/test_models')

describe 'GET /events/:id', () ->

  guest = new TestUser('get_events_id_guest')
  host  = new TestUser('get_events_id_host')
  constable = new TestUser('get_events_id_constable', roles: ['constable'])
  swap  = new TestSwap('get_events_id_swap', host)
  event = new TestEvent('get_events_id', [guest], [host], swap)
  eventPre = new TestEvent('get_events_id_pre', [guest], [host], swap, state: 'prefilter')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## create users, swap, and event
    async.series [
      (cb) -> async.parallel [
        guest.create, host.create, constable.create
      ], cb
      swap.create
      (cb) -> async.parallel([event.create, eventPre.create], cb)
    ], ready

  after (finished) ->
    ## destroy event and swap, then users
    async.series [
      (cb) -> async.parallel [
        event.destroy, eventPre.destroy, swap.destroy
      ], cb
      (cb) -> async.parallel [
        guest.destroy, host.destroy, constable.destroy
      ], cb
    ], finished


  describe 'usual event', () ->

    it 'should GET the event', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/events/#{event._id}"
        json: true
        headers: cookie: guest.cookie
      request opts, (err, res, eventDoc) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        eventDoc.should.have.property('guests')
        eventDoc.guests.should.eql([guest._id])
        delete eventDoc.guests
        eventDoc.should.have.property('hosts')
        eventDoc.hosts.should.eql([host._id])
        delete eventDoc.hosts
        eventDoc.should.eql(event.attributes())
        done()


    it 'should GET the event for constable', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/events/#{event._id}"
        json: true
        headers: cookie: constable.cookie
      request opts, (err, res, eventDoc) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        eventDoc.should.have.property('guests')
        eventDoc.guests.should.eql([guest._id])
        delete eventDoc.guests
        eventDoc.should.have.property('hosts')
        eventDoc.hosts.should.eql([host._id])
        delete eventDoc.hosts
        eventDoc.should.eql(event.attributes())
        done()


  describe 'prefilter event', () ->
    it 'should GET the event for guest', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/events/#{eventPre._id}"
        json: true
        headers: cookie: guest.cookie
      request opts, (err, res, eventDoc) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        eventDoc.should.have.property('guests')
        eventDoc.guests.should.eql([guest._id])
        delete eventDoc.guests
        eventDoc.should.have.property('hosts')
        eventDoc.hosts.should.eql([host._id])
        delete eventDoc.hosts
        eventDoc.should.eql(eventPre.attributes())
        done()

    it 'should _not_ GET the event for host (404)', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/events/#{eventPre._id}"
        json: true
        headers: cookie: host.cookie
      request opts, (err, res, eventDoc) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 404)
        done()

    it 'should GET the event for constable', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/events/#{eventPre._id}"
        json: true
        headers: cookie: constable.cookie
      request opts, (err, res, eventDoc) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        eventDoc.should.have.property('guests')
        eventDoc.guests.should.eql([guest._id])
        delete eventDoc.guests
        eventDoc.should.have.property('hosts')
        eventDoc.hosts.should.eql([host._id])
        delete eventDoc.hosts
        eventDoc.should.eql(eventPre.attributes())
        done()
