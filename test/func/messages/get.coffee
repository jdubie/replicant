should  = require('should')
async   = require('async')
request = require('request')
config  = require('config')
debug   = require('debug')('replicant/test/func/phone_numbers/delete')

{TestUser, TestSwap, TestEvent, TestMessage} = require('lib/test_models')


describe 'GET /messages', () ->

  guest     = new TestUser('get_messages_guest')
  host      = new TestUser('get_messages_host')
  constable = new TestUser('get_messages_constable', roles: ['constable'])
  swap      = new TestSwap('get_messages_swap', host)
  event     = new TestEvent('get_messages_event', [guest], [host], swap)
  message1  = new TestMessage('get_messages_1', guest, event)
  message2  = new TestMessage('get_messages_2', guest, event)

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel([constable.create, guest.create, host.create, swap.create], cb)
      event.create
      message1.create
      message2.create
    ], ready

  after (finished) ->
    async.series [
      message1.destroy
      message2.destroy
      event.destroy
      (cb) -> async.parallel([constable.destroy, guest.destroy, host.destroy, swap.destroy], cb)
    ], finished

  it 'should GET all messages w/ correct read status', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages"
      json: true
      headers: cookie: guest.cookie
    request opts, (err, res, messageDocs) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      messages = [message1.attributes(), message2.attributes()]
      messageDocs.should.eql(messages)
      done()

  it 'should make sure messages are actually in constable db', (done) ->
    getMessage = (id, callback) -> config.db.constable().get(id, callback)
    ids = [message1._id, message2._id]
    async.map ids, getMessage, (err, messageDocs) ->
      should.not.exist(err)
      messages = [message1.attributes(), message2.attributes()]
      delete message.read for message in messages
      messageDocs.should.eql(messages)
      done()

  it 'should allow constable view all messages and they should be unread', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages"
      json: true
      headers: cookie: constable.cookie
    request opts, (err, res, messageDocs) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      messages = [message1.attributes(), message2.attributes()]
      message.read = false for message in messages
      messageDocs.should.eql(messages)
      done()
