should  = require('should')
async   = require('async')
request = require('request')
kue     = require('kue')
debug   = require('debug')('replicant:/test/func/event/post')

config  = require('config')
{TestUser, TestSwap, TestEvent} = require('lib/test_models')


describe 'POST /events', () ->

  guest = new TestUser('post_events_guest')
  host  = new TestUser('post_events_host')
  swap  = new TestSwap('post_events_swap', host)
  opts  = hosts: [host], guests: [guest]
  event = new TestEvent('post_events_id', [guest], [host], swap, opts)

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel([guest.create, host.create], cb)
      swap.create
      (cb) -> config.jobs.client.flushall(cb)
    ], ready

  after (finished) ->
    async.series [
      (cb) -> async.parallel([event.destroy, swap.destroy], cb)
      (cb) -> async.parallel([guest.destroy, host.destroy], cb)
      (cb) -> config.jobs.client.flushall(cb)
    ], finished


  it 'should POST without failure', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/events"
      json: event.attributes()
      headers: cookie: guest.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 201)
      returnedFields = ['_rev', 'mtime', 'ctime', 'guests', 'hosts', 'requested_time']
      body.should.have.keys(returnedFields)
      for key, val of body when key not in ['guests', 'hosts']
        event[key] = val
      done()

  it 'should create an event in the \'mapper\' DB', (done) ->
    mapperDb = config.db.mapper()
    mapperDb.get event._id, (err, mapperDoc) ->
      should.not.exist(err)
      mapperDoc.should.have.property('guests')
      mapperDoc.guests.should.eql([guest._id])
      mapperDoc.should.have.property('hosts')
      mapperDoc.hosts.should.eql([host._id])
      done()

  it 'should create an event document for involved users', (done) ->
    _event = event.attributes()
    delete _event.hosts
    delete _event.guests
    checkEventDoc = (user, callback) ->
      userDb = config.db.user(user._id)
      userDb.get event._id, (err, eventDoc) ->
        should.not.exist(err)
        eventDoc.should.eql(_event)
        callback()
    async.parallel [
      (cb) -> checkEventDoc(guest, cb)
      (cb) -> checkEventDoc(host, cb)
    ], done

  it 'should create event.create notification on work queue', (done) ->
    kue.Job.get 1, (err, job) ->
      should.not.exist(err)
      should.exist(job)
      job.should.have.property('type', 'notification.event.create')
      job.should.have.property('data')
      job.data.should.have.property('hosts')
      job.data.should.have.property('guests')
      job.data.hosts.should.eql([host._id])
      job.data.guests.should.eql([guest._id])
      job.data.should.have.property('swap')
      job.data.should.have.property('event')
      job.data.event.should.have.property('_id', event._id)
      job.data.swap.should.have.property('_id', event.swap_id)
      done()


  it 'should 400 on bad input', (done) ->
    verifyField = (field, callback) ->
      json = event.attributes()
      value = json[field]
      delete json[field]
      opts =
        url: "http://localhost:3001/events"
        method: 'POST'
        json: json
        headers: cookie: guest.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 400)
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property(field)

        json[field] = value
        callback()
    async.map(['_id', 'swap_id', 'state'], verifyField, done)
