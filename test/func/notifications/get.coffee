should  = require('should')
async   = require('async')
request = require('request')
config  = require('config')
debug   = require('debug')('replicant/test/func/phone_numbers/delete')

{TestUser, TestSwap, TestEvent, TestNotification} = require('lib/test_models')


describe 'zzz GET /notifications', () ->

  guest     = new TestUser('get_noties_guest')
  host      = new TestUser('get_noties_host')
  constable = new TestUser('get_noties_constable', roles: ['constable'])
  swap      = new TestSwap('get_noties_swap', host)
  event     = new TestEvent('get_noties_event', [guest], [host], swap)
  noti1 = new TestNotification(
    'get_noties_1', guest, host, event, action: 'approved'
  )
  noti2 = new TestNotification(
    'get_noties_2', guest, host, event, action: 'declined'
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

  it 'should GET all notifications w/ correct read status', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/notifications"
      json: true
      headers: cookie: guest.cookie
    request opts, (err, res, notiDocs) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      noties = [noti1.attributes(), noti2.attributes()]
      notiDocs.should.eql(noties)
      done()

  it 'should make sure notifications are in constable db', (done) ->
    getNoti = (id, callback) -> config.db.constable().get(id, callback)
    async.map [noti1._id, noti2._id], getNoti, (err, notiDocs) ->
      should.not.exist(err)
      noties = [noti1.attributes(), noti2.attributes()]
      delete noti.read for noti in noties
      notiDocs.should.eql(noties)
      done()

  it 'should get unread notifications for constable', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/notifications"
      json: true
      headers: cookie: constable.cookie
    request opts, (err, res, notiDocs) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      noties = [noti1.attributes(), noti2.attributes()]
      noti.read = false for noti in noties
      notiDocs.should.eql(noties)
      done()
