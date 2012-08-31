should = require('should')
async = require('async')
util = require('util')
request = require('request')

config = require('config')
h = require('lib/helpers')


describe 'GET /payments/:id', () ->

  ## from the test/toy data
  _username = h.hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _payment =
    _id: 'getpaymentsid'
    type: 'payment'
    name: _username
    user_id: _userId
    event_id: 'eventid'
    card_id: 'cardid'
    status: "1"
    ctime: _ctime
    mtime: _mtime
  _cookie = null

  mainDb = config.nanoAdmin.db.use('lifeswap')
  userDb = config.nanoAdmin.db.use(h.getUserDbName(userId: _userId))


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
    insertPayment = (cb) ->
      userDb.insert _payment, _payment._id, (err, res) ->
        if err then console.error err
        _payment._rev = res.rev
        cb()
    ## in parallel
    async.parallel [
      authUser
      insertPayment
    ], (err, res) ->
      ready()


  after (finished) ->
    ## destroy payment
    userDb.destroy(_payment._id, _payment._rev, finished)


  it 'should GET the payment', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/payments/#{_payment._id}"
      json: true
      headers: cookie: _cookie
    request opts, (err, res, payment) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      payment.should.eql(_payment)
      done()
