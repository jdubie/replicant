should = require('should')
async = require('async')
request = require('request')
_ = require('underscore')

{kueUrl, jobs, nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestSwap, TestEvent, TestMessage} = require('lib/test_models')

describe 'POST /messages', () ->

  guest   = new TestUser('post_messages_guest')
  host    = new TestUser('post_messages_host')
  swap    = new TestSwap('post_messages_swap', host)
  event   = new TestEvent('post_messages_event', [guest], [host], swap)
  message = new TestMessage('post_messages', guest, event)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## create users and swap, then event
    async.series [
      (cb) -> async.parallel([guest.create, host.create, swap.create], cb)
      event.create
      (cb) -> jobs.client.flushall(cb)
    ], ready


  after (finished) ->
    ## destroy message -> event -> users and swap
    async.series [
      message.destroy
      event.destroy
      (cb) -> async.parallel([guest.destroy, host.destroy, swap.destroy], cb)
      (cb) -> jobs.client.flushall(cb)
    ], finished

  it 'should POST without failure', (done) ->
    _message = message.attributes()
    delete _message.read
    opts =
      method: 'POST'
      url: "http://localhost:3001/messages"
      json: _message
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
      userDbName = getUserDbName(userId: user._id)
      userDb = nanoAdmin.db.use(userDbName)
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
      userDbName = getUserDbName(userId: user._id)
      userDb = nanoAdmin.db.use(userDbName)
      opts = key: [message.event_id, message._id]
      userDb.view 'userddoc', 'messages', opts, (err, res) ->
        should.not.exist(err)
        res.should.have.property('rows').with.lengthOf(1)
        if user._id is guest._id     ## read
          res.rows[0].should.have.property('value', 0)
        else                        ## unread
          res.rows[0].should.have.property('value', 1)
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
