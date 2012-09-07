should  = require('should')
async   = require('async')
request = require('request')

{TestUser, TestSwap, TestEvent, TestMessage} = require('lib/test_models')
{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'yyy GET /messages/:id', () ->

  guest   = new TestUser('get_messages_id_guest')
  host    = new TestUser('get_messages_id_host')
  swap    = new TestSwap('get_messages_id_swap', host)
  event   = new TestEvent('get_messages_id_event', [guest], [host], swap)
  message = new TestMessage('get_messages_id', guest, event)

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel([guest.create, host.create, swap.create], cb)
      event.create
      message.create
    ], ready

  after (finished) ->
    async.series [
      message.destroy
      event.destroy
      (cb) -> async.parallel([guest.destroy, host.destroy, swap.destroy], cb)
    ], finished

  it 'should GET _read_ message correctly', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages/#{message._id}"
      json: true
      headers: cookie: guest.cookie
    request opts, (err, res, messageDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      message.read = true
      messageDoc.should.eql(message.attributes())
      done()

  it 'should GET _unread_ message correctly', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages/#{message._id}"
      json: true
      headers: cookie: host.cookie
    request opts, (err, res, messageDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      message.read = false
      messageDoc.should.eql(message.attributes())
      done()
