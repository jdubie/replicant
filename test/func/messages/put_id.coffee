should  = require('should')
async   = require('async')
request = require('request')

{TestUser, TestSwap, TestEvent, TestMessage} = require('lib/test_models')
{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'yyy PUT /messages/:id', () ->

  guest   = new TestUser('put_messages_id_guest')
  host    = new TestUser('put_messages_id_host')
  swap    = new TestSwap('put_messages_id_swap', host)
  event   = new TestEvent('put_messages_id_event', [guest], [host], swap)
  message = new TestMessage('put_messages_id', guest, event, read: false)

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

  it 'should return 201 when marking read', (done) ->
    message.read = true
    opts =
      method: 'PUT'
      url: "http://localhost:3001/messages/#{message._id}"
      json: message.attributes()
      headers: cookie: guest.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 201)
      done()

  it 'should mark the message as \'read\'', (done) ->
    userDb = nanoAdmin.db.use(getUserDbName(userId: guest._id))
    opts =
      key: [message.event_id, message._id]
    userDb.view 'userddoc', 'messages', opts, (err, res) ->
      should.not.exist(err)
      res.should.have.property('rows').with.lengthOf(1)
      res.rows[0].should.have.property('value', 0)
      done()

  it 'should return 201 when marking unread', (done) ->
    message.read = false
    opts =
      method: 'PUT'
      url: "http://localhost:3001/messages/#{message._id}"
      json: message.attributes()
      headers: cookie: guest.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      done()

  it 'should mark the message as \'unread\'', (done) ->
    userDb = nanoAdmin.db.use(getUserDbName(userId: guest._id))
    opts =
      key: [message.event_id, message._id]
    userDb.view 'userddoc', 'messages', opts, (err, res) ->
      should.not.exist(err)
      res.should.have.property('rows').with.lengthOf(1)
      res.rows[0].should.have.property('value', 1)
      done()

  it 'should not change message for any involved users', (done) ->
    checkMessageDoc = (user, callback) ->
      userId = user._id
      userDbName = getUserDbName({userId})
      userDb = nanoAdmin.db.use(userDbName)
      userDb.get message._id, (err, messageDoc) ->
        should.not.exist(err)
        _message = message.attributes()
        delete _message.read
        messageDoc.should.eql(_message)
        callback()
    async.map [guest, host], checkMessageDoc, (err, res) ->
      should.not.exist(err)
      done()
