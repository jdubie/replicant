should = require('should')
async = require('async')
util = require('util')
request = require('request')
debug = require('debug')('replicant/test/func/message/delete_id')

{TestUser, TestSwap, TestEvent, TestMessage} = require('lib/test_models')
{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'DELETE /messages/:id', () ->

  guest   = new TestUser('delete_messages_id_user1')
  host    = new TestUser('delete_messages_id_user2')
  swap    = new TestSwap('delete_messages_id_swap', host)
  event   = new TestEvent('delete_messages_id_event', [guest], [host], swap)
  message = new TestMessage('delete_messages_id', guest, event)

  mainDb = nanoAdmin.db.use('lifeswap')
  mapperDb = nanoAdmin.db.use('mapper')

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')

      async.series [
        (cb) -> async.parallel([guest.create, host.create], cb)
        event.create
        message.create
      ], ready

    after (finished) ->
      async.series [
        #message.destroy
        event.destroy
        (cb) -> async.parallel([guest.destroy, host.destroy], cb)
      ], finished

    it 'should respond with 403 to DELETE /messages/:id', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/messages/#{message._id}"
        json: message.attributes()
        headers: cookie: guest.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(403)
        done()

    it 'should not delete message for any involved users', (done) ->
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
