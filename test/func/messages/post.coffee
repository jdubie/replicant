should = require('should')
async = require('async')
request = require('request')
_ = require('underscore')

config = require('config')
{TestUser, TestSwap, TestEvent, TestMessage} = require('lib/test_models')

describe 'POST /messages', () ->

  guest     = new TestUser('post_messages_guest')
  host      = new TestUser('post_messages_host')
  constable = new TestUser('post_messages_host_constable', roles: ['constable'])
  swap      = new TestSwap('post_messages_swap', host)
  event     = new TestEvent('post_messages_event', [guest], [host], swap)
  message   = new TestMessage('post_messages', guest, event)
  messageC  = new TestMessage('post_messagesC', constable, event)

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel([constable.create, guest.create, host.create, swap.create], cb)
      event.create
      (cb) -> config.jobs.client.flushall(cb)
    ], ready

  after (finished) ->
    async.series [
      message.destroy
      messageC.destroy
      event.destroy
      (cb) -> async.parallel([constable.destroy, guest.destroy, host.destroy, swap.destroy], cb)
      (cb) -> config.jobs.client.flushall(cb)
    ], finished

  describe 'normal user', () ->

    it 'should POST without failure', (done) ->
      opts =
        method: 'POST'
        url: "http://localhost:3001/messages"
        json: message.attributes()
        headers: cookie: guest.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        body.should.have.keys(['_rev', 'ctime', 'mtime'])
        for key, val of body
          message[key] = val
        done()

    it 'should replicate the message to all involved users', (done) ->
      checkMessageDoc = (user, cb) ->
        userDb = config.db.user(user._id)
        userDb.get message._id, (err, messageDoc) ->
          should.not.exist(err)
          _message = message.attributes()
          delete _message.read
          messageDoc.should.eql(_message)
          cb()
      async.parallel [
        (cb) -> checkMessageDoc(guest, cb)
        (cb) -> checkMessageDoc(host, cb)
      ], done

    it 'should mark the message as read for the author', (done) ->
      checkMessageReadStatus = (user, cb) ->
        userDb = config.db.user(user._id)
        opts = key: message._id
        userDb.view 'userddoc', 'read', opts, (err, res) ->
          should.not.exist(err)
          if user._id is guest._id     ## read
            res.should.have.property('rows').with.lengthOf(1)
          else                        ## unread
            res.should.have.property('rows').with.lengthOf(0)
          cb()
      async.parallel [
        (cb) -> checkMessageReadStatus(guest, cb)
        (cb) -> checkMessageReadStatus(host, cb)
      ], done

    it 'should add notification to work queue', (done) ->
      require('kue').Job.get 1, (err, job) ->
        should.not.exist(err)
        job.should.have.property('type', 'notification.message')
        job.should.have.property('data')
        job.data.should.have.property('message')
        job.data.message.should.have.property('message')
        job.data.message.message.should.equal(message.message)
        done()

  describe 'constable user', () ->

    it 'should POST correctly for constable', (done) ->
      opts =
        method: 'POST'
        url: "http://localhost:3001/messages"
        json: messageC.attributes()
        headers: cookie: constable.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        body.should.have.keys(['_rev', 'ctime', 'mtime'])
        for key, val of body
          message[key] = val
        done()

    it 'should write a read doc to the constable\'s user db', (done) ->
      userDb = config.db.user(constable._id)
      opts = key: messageC._id
      userDb.view 'userddoc', 'read', opts, (err, res) ->
        should.not.exist(err)
        res.should.have.property('rows').with.lengthOf(1)
        done()
