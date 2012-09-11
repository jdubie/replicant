should = require('should')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestSwap, TestEvent} = require('lib/test_models')


describe 'DELETE /events/:id', () ->

  guest = new TestUser('delete_events_id_guest')
  host  = new TestUser('delete_events_id_host')
  swap  = new TestSwap('delete_events_id_swap', host)
  event = new TestEvent('delete_events_id', [guest], [host], swap)

  userDb = nanoAdmin.db.use(getUserDbName(userId: guest._id))

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel([guest.create, host.create], cb)
      swap.create
      event.create
    ], ready

  after (finished) ->
    async.series [
      (cb) -> async.parallel([event.destroy, swap.destroy], cb)
      (cb) -> async.parallel([guest.destroy, host.destroy], cb)
    ], finished

  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/swaps/#{guest._id}"
      json: true
      headers: cookie: guest.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'event\' type entry in user db', (done) ->
    userDb.get event._id, (err, eventDoc) ->
      should.not.exist(err)
      eventDoc.should.eql(event.attributes())
      done()
