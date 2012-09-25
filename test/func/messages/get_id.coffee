should  = require('should')
async   = require('async')
request = require('request')
config  = require('config')

{TestUser, TestSwap, TestEvent, TestMessage} = require('lib/test_models')


describe 'GET /messages/:id', () ->

  guest   = new TestUser('get_messages_id_guest')
  host    = new TestUser('get_messages_id_host')
  constable = new TestUser('get_messages_constable', roles: ['constable'])
  swap    = new TestSwap('get_messages_id_swap', host)
  event   = new TestEvent('get_messages_id_event', [guest], [host], swap)
  message = new TestMessage('get_messages_id_1', guest, event, read: true)
  message2 = new TestMessage('get_messages_id_2', guest, event, read: false)
  message3 = new TestMessage('get_messages_id_3', constable, event, read: true)
  message4 = new TestMessage('get_messages_id_4', constable, event, read: false)

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel [
        constable.create
        guest.create
        host.create
        swap.create
      ], cb
      event.create
      (cb) -> async.parallel [
        message.create
        message2.create
        message3.create
        message4.create
      ], cb
    ], ready

  after (finished) ->
    async.series [
      (cb) -> async.parallel [
        message4.destroy
        message3.destroy
        message2.destroy
        message.destroy
      ], cb
      event.destroy
      (cb) -> async.parallel [
        constable.destroy
        guest.destroy
        host.destroy
        swap.destroy
      ], cb
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
      messageDoc.should.eql(message.attributes())

      # sanity checks
      messageDoc.should.have.property('read', true)
      message.attributes().should.have.property('read', true)
      done()

  it 'should GET _unread_ message correctly', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages/#{message2._id}"
      json: true
      headers: cookie: host.cookie
    request opts, (err, res, messageDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      messageDoc.should.eql(message2.attributes())

      # sanity checks
      messageDoc.should.have.property('read', false)
      message2.attributes().should.have.property('read', false)
      done()

  it 'should make sure messages are actually in constable db', (done) ->
    config.db.constable().get message._id, (err, _message) ->
      should.not.exist(err)
      msg = message.attributes()
      delete msg.read
      _message.should.eql(msg)
      done()

  it 'should GET _read_ messages for constable', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages/#{message3._id}"
      json: true
      headers: cookie: constable.cookie
    request opts, (err, res, messageDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      messageDoc.should.eql(message3.attributes())

      # sanity checks
      messageDoc.should.have.property('read', true)
      message3.attributes().should.have.property('read', true)
      done()

  it 'should GET _unread_ messages for constable', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages/#{message4._id}"
      json: true
      headers: cookie: constable.cookie
    request opts, (err, res, messageDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      messageDoc.should.eql(message4.attributes())

      # sanity checks
      messageDoc.should.have.property('read', false)
      message4.attributes().should.have.property('read', false)
      done()
