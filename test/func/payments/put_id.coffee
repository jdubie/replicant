should = require('should')
async = require('async')
request = require('request')

config = require('config')
h = require('lib/helpers')


describe 'PUT /payments/:id', () ->

  _username = h.hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _payment =
    _id: 'putpaymentid'
    type: 'payment'
    name: _username
    user_id: _userId
    event_id: 'eventid'
    card_id: 'cardid'
    status: "1"
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'
  _cookie = null

  userDb = config.nanoAdmin.db.use(h.getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      config.nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        _cookie = headers['set-cookie'][0]
        callback()
    ## insert payment
    insertPayment = (callback) ->
      userDb.insert _payment, (err, res) ->
        should.not.exist(err)
        _payment._rev = res.rev
        callback()

    async.series [
      authUser
      insertPayment
    ], ready


  after (finished) ->
    ## destroy payment
    userDb.get _payment._id, (err, payment) ->
      should.not.exist(err)
      userDb.destroy(payment._id, payment._rev, finished)


  it 'should PUT the payment correctly', (done) ->
    _payment.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/payments/#{_payment._id}"
      json: _payment
      headers: cookie: _cookie
    request opts, (err, res, payment) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      payment.should.have.keys(['_rev', 'mtime'])
      done()
