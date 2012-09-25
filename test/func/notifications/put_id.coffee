should  = require('should')
async   = require('async')
request = require('request')

config  = require('config')
{TestUser, TestSwap, TestEvent, TestNotification} = require('lib/test_models')


describe 'PUT /notifications/:id', () ->

  guest     = new TestUser('put_notis_id_guest')
  host      = new TestUser('put_notis_id_host')
  constable = new TestUser('put_notis_id_constable', roles: ['constable'])
  swap      = new TestSwap('put_notis_id_swap', host)
  event     = new TestEvent('put_notis_id_event', [guest], [host], swap)
  noti      = new TestNotification(
    'put_notis_id', guest, host, event, action: 'approved', read: false
  )

  before (ready) ->
    app = require('app')
    async.series [
      (cb) -> async.parallel [
        guest.create
        host.create
        constable.create
        swap.create
      ], cb
      event.create
      noti.create
    ], ready

  after (finished) ->
    async.series [
      noti.destroy
      event.destroy
      (cb) -> async.parallel [
        guest.destroy
        host.destroy
        constable.destroy
        swap.destroy
      ], cb
    ], finished


  describe 'regular user', () ->

    it 'should 400 on bad input', (done) ->
      json = noti.attributes()
      verifyField = (field, callback) ->
        value = json[field]
        delete json[field]
        opts =
          method: 'PUT'
          url: "http://localhost:3001/notifications/#{noti._id}"
          json: json
          headers: cookie: guest.cookie
        request opts, (err, res, body) ->
          should.not.exist(err)
          res.should.have.property('statusCode', 400)
          body.should.have.keys(['error', 'reason'])
          body.reason.should.have.property(field)

          json[field] = value
          callback()
      async.map(['_id', 'read'], verifyField, done)

    it 'should return 201 when marking read', (done) ->
      noti.read = true
      opts =
        method: 'PUT'
        url: "http://localhost:3001/notifications/#{noti._id}"
        json: noti.attributes()
        headers: cookie: guest.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        done()

    it 'should mark the notification as \'read\'', (done) ->
      userDb = config.db.user(guest._id)
      opts = key: noti._id
      userDb.view 'userddoc', 'read', opts, (err, res) ->
        should.not.exist(err)
        res.should.have.property('rows').with.lengthOf(1)
        done()

    it 'should return 201 when marking unread', (done) ->
      noti.read = false
      opts =
        method: 'PUT'
        url: "http://localhost:3001/notifications/#{noti._id}"
        json: noti.attributes()
        headers: cookie: guest.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        done()

    it 'should mark the notification as \'unread\'', (done) ->
      userDb = config.db.user(guest._id)
      opts = key: noti._id
      userDb.view 'userddoc', 'read', opts, (err, res) ->
        should.not.exist(err)
        res.should.have.property('rows').with.lengthOf(0)
        done()


  describe 'constable', () ->

    it 'should 400 on bad input', (done) ->
      json = noti.attributes()
      verifyField = (field, callback) ->
        value = json[field]
        delete json[field]
        opts =
          method: 'PUT'
          url: "http://localhost:3001/notifications/#{noti._id}"
          json: json
          headers: cookie: constable.cookie
        request opts, (err, res, body) ->
          should.not.exist(err)
          res.should.have.property('statusCode', 400)
          body.should.have.keys(['error', 'reason'])
          body.reason.should.have.property(field)

          json[field] = value
          callback()
      async.map(['_id', 'read'], verifyField, done)

    it 'should return 201 when marking read', (done) ->
      noti.read = true
      opts =
        method: 'PUT'
        url: "http://localhost:3001/notifications/#{noti._id}"
        json: noti.attributes()
        headers: cookie: constable.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        done()

    it 'should mark the notification as \'read\'', (done) ->
      userDb = config.db.user(constable._id)
      opts = key: noti._id
      userDb.view 'userddoc', 'read', opts, (err, res) ->
        should.not.exist(err)
        res.should.have.property('rows').with.lengthOf(1)
        done()

    it 'should return 201 when marking unread', (done) ->
      noti.read = false
      opts =
        method: 'PUT'
        url: "http://localhost:3001/notifications/#{noti._id}"
        json: noti.attributes()
        headers: cookie: constable.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        done()

    it 'should mark the notification as \'unread\'', (done) ->
      userDb = config.db.user(constable._id)
      opts = key: noti._id
      userDb.view 'userddoc', 'read', opts, (err, res) ->
        should.not.exist(err)
        res.should.have.property('rows').with.lengthOf(0)
        done()
