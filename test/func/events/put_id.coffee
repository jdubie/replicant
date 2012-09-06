should  = require('should')
async   = require('async')
util    = require('util')
request = require('request')
kue     = require('kue')

{nanoAdmin, jobs} = require('config')
{getUserDbName} = require('lib/helpers')
{EVENT_STATE} = require('../../../../lifeswap/userdb/shared/constants')
{TestUser, TestSwap, TestEvent} = require('lib/test_models')


describe 'yyy PUT /events/:id', () ->

  guest = new TestUser('put_events_id_guest')
  host  = new TestUser('put_events_id_host')
  swap  = new TestSwap('put_events_id_swap', host)
  event = new TestEvent('put_events_id', [guest], [host], swap)

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
      (cb) -> jobs.client.flushall(cb)    ## move this into parallel
    ], finished

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

  it 'should reflect the change in all users DBs', (done) ->
    getEvent = (user, callback) ->
      userDb = nanoAdmin.db.use(getUserDbName(userId: user._id))
      userDb.get event._id, (err, eventDoc) ->
        should.not.exist(err)
        eventDoc.should.eql(event.attributes())
        callback()
    async.parallel [
      (cb) -> getEvent(guest, cb)
      (cb) -> getEvent(host, cb)
    ], done

  it 'should queue up emails to be sent to the users', (done) ->
    kue.Job.get 1, (err, res) ->
      console.error err if err?
      res.should.have.property('data')
      res.data.should.have.property('event')
      res.data.should.have.property('userId', host._id)
      res.data.should.have.property('rev')
      done()
