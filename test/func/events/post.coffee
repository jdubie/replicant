should = require('should')
async = require('async')
util = require('util')
request = require('request')
debug = require('debug')('replicant:/test/func/event/post')
kue = require('kue')

{kueUrl, jobs, nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestSwap, TestEvent} = require('lib/test_models')


describe 'yyy POST /events', () ->

  guest = new TestUser('post_events_guest')
  host  = new TestUser('post_events_host')
  swap  = new TestSwap('post_events_swap', host)
  event = new TestEvent('post_events_id', [guest], [host], swap)

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel([guest.create, host.create], cb)
      swap.create
      (cb) -> jobs.client.flushall(cb)
    ], ready

  after (finished) ->
    async.series [
      (cb) -> async.parallel([event.destroy, swap.destroy], cb)
      (cb) -> async.parallel([guest.destroy, host.destroy], cb)
      (cb) -> jobs.client.flushall(cb)
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
      returnedFields = ['_rev', 'mtime', 'ctime', 'guests', 'hosts']
      body.should.have.keys(returnedFields)
      for key, val of body when not (key in ['guests', 'hosts'])
        event[key] = val
      done()

  it 'should create an event in the \'mapper\' DB', (done) ->
    mapperDb = nanoAdmin.db.use('mapper')
    mapperDb.get event._id, (err, mapperDoc) ->
      should.not.exist(err)
      mapperDoc.should.have.property('guests')
      mapperDoc.guests.should.eql([guest._id])
      mapperDoc.should.have.property('hosts')
      mapperDoc.hosts.should.eql([host._id])
      done()

  it 'should create an event document for involved users', (done) ->
    checkEventDoc = (user, callback) ->
      userDbName = getUserDbName(userId: user._id)
      userDb = nanoAdmin.db.use(userDbName)
      userDb.get event._id, (err, eventDoc) ->
        should.not.exist(err)
        eventDoc.should.eql(event.attributes())
        callback()
    async.parallel [
      (cb) -> checkEventDoc(guest, cb)
      (cb) -> checkEventDoc(host, cb)
    ], done

    #  it 'should create event.create notification on work queue', (done) ->
    #    kue.Job.get 1, (err, job) ->
    #      should.not.exist(err)
    #      job.should.have.property('type', 'notification.event.create')
    #      job.should.have.property('data')
    #      job.data.should.have.property('hosts')
    #      job.data.should.have.property('guests')
    #      job.data.hosts.should.eql([host._id])
    #      job.data.guests.should.eql([guest._id])
    #      job.data.should.have.property('swap')
    #      job.data.should.have.property('event')
    #      job.data.event.should.have.property('_id', event._id)
    #      job.data.swap.should.have.property('_id', event.swap_id)
    #      done()
