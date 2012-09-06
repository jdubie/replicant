should = require('should')
async = require('async')
request = require('request')
debug = require('debug')('replicant/test/func/phone_numbers/delete')

{TestUser, TestSwap, TestEvent, TestMessage} = require('lib/test_models')
{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'yyyy GET /messages', () ->

  guest   = new TestUser('delete_messages_id_user1')
  host    = new TestUser('delete_messages_id_user2')
  swap    = new TestSwap('delete_messages_id_swap', host)
  event   = new TestEvent('delete_messages_id_event', [guest], [host], swap)
  message = new TestMessage('delete_messages_id', guest, event)

  mainDb = nanoAdmin.db.use('lifeswap')
  userDb = nanoAdmin.db.use(getUserDbName(userId: guest._id))

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel([guest.create, host.create, swap.create], cb)
      event.create
      message.create
    ], ready

  after (finished) ->
    async.series [
      event.destroy
      (cb) -> async.parallel([guest.destroy, host.destroy, swap.destroy], cb)
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
      guest.getMessages (err, messages) ->
        messageDocs.should.eql(messages)
        done()
