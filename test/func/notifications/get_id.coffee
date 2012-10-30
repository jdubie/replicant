should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)
config  = require('config')

{TestUser, TestSwap, TestEvent, TestNotification} = require('lib/test_models')


describe 'GET /notifications/:id', () ->

  guest     = new TestUser('get_noties_id_guest')
  host      = new TestUser('get_noties_id_host')
  constable = new TestUser('get_noties_id_constable', roles: ['constable'])
  swap      = new TestSwap('get_noties_id_swap', host)
  event     = new TestEvent('get_noties_id_event', [guest], [host], swap)
  noti1 = new TestNotification(
    'get_noties_id_1', guest, host, event, action: 'approved', read: true
  )
  noti2 = new TestNotification(
    'get_noties_id_2', guest, host, event, action: 'declined', read: false
  )

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
        noti1.create
        noti2.create
      ], cb
    ], ready

  after (finished) ->
    async.series [
      (cb) -> async.parallel [
        noti1.destroy
        noti2.destroy
      ], cb
      event.destroy
      (cb) -> async.parallel [
        constable.destroy
        guest.destroy
        host.destroy
        swap.destroy
      ], cb
    ], finished

  it 'should GET each notifications w/ correct read status', (done) ->
    getNoti = (noti, callback) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/notifications/#{noti._id}"
        json: true
        headers: cookie: guest.cookie
      request opts, (err, res, notiDoc) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        notiDoc.should.eql(noti.attributes())
        callback()
    async.map([noti1, noti2], getNoti, done)

  it 'should make sure _unread_ notifications are in constable db', (done) ->
    getNoti = (noti, callback) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/notifications/#{noti._id}"
        json: true
        headers: cookie: constable.cookie
      request opts, (err, res, notiDoc) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        notiComp = noti.attributes()
        notiComp.read = false
        notiDoc.should.eql(notiComp)
        callback()
    async.map([noti1, noti2], getNoti, done)
