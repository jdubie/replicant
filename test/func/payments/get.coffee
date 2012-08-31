should = require('should')
async = require('async')
request = require('request')

config = require('config')
h = require('lib/helpers')


describe 'GET /payments', () ->

  ## from the test/toy data
  _username = h.hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _payments = [
    {
      _id: 'getpayments1'
      type: 'payment'
      name: _username
      user_id: _userId
      event_id: 'eventid'
      card_id: 'cardid'
      status: "1"
      ctime: _ctime
      mtime: _mtime
    }
    {
      _id: 'getpayments2'
      type: 'payment'
      name: _username
      user_id: _userId
      event_id: 'eventid'
      card_id: 'cardid'
      status: "2"
      ctime: _ctime
      mtime: _mtime
    }
  ]
  _cookie = null

  mainDb = config.nanoAdmin.db.use('lifeswap')
  userDb = config.nanoAdmin.db.use(h.getUserDbName(userId: _userId))

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')
      ## authenticate user
      authUser = (cb) ->
        config.nano.auth _username, _password, (err, body, headers) ->
          should.not.exist(err)
          should.exist(headers and headers['set-cookie'])
          _cookie = headers['set-cookie'][0]
          cb()
      ## insert payment
      insertPayment = (payment, cb) ->
        userDb.insert payment, payment._id, (err, res) ->
          payment._rev = res.rev
          cb()
      insertPayments = (cb) -> async.map(_payments, insertPayment, cb)
      ## in parallel
      async.parallel [
        authUser
        insertPayments
      ], ready


    after (finished) ->
      ## destroy payments
      destroyPayment = (payment, callback) ->
        userDb.destroy(payment._id, payment._rev, callback)
      ## in parallel
      async.map(_payments, destroyPayment, finished)


    it 'should GET all payments', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/payments"
        json: true
        headers: cookie: _cookie
      request opts, (err, res, payments) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        payments.should.eql(_payments)
        done()
