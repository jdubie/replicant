should = require('should')
async = require('async')
request = require('request')

{TestUser, TestSwap, TestEvent} = require('lib/test_models')

describe 'yyy GET /events/:id', () ->

  guest = new TestUser('get_events_id_guest')
  host  = new TestUser('get_events_id_host')
  swap  = new TestSwap('get_events_id_swap', host)
  event = new TestEvent('get_events_id', [guest], [host], swap)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## create users, swap, and event
    async.series [
      (cb) -> async.parallel([guest.create, host.create], cb)
      swap.create
      event.create
    ], ready

  after (finished) ->
    ## destroy event and swap, then users
    async.series [
      (cb) -> async.parallel([event.destroy, swap.destroy], cb)
      (cb) -> async.parallel([guest.destroy, host.destroy], cb)
    ], finished


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
