should = require('should')
async = require('async')
request = require('request')

config = require('config')
h = require('lib/helpers')


describe 'DELETE /payments/:id', () ->

  ## simple test - for now should just 403 (forbidden)
  _username = h.hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _payment =
    _id: 'deletepaymentid'
    type: 'payment'
    name: _username
    user_id: _userId
    event_id: 'eventid'
    card_id: 'cardid'
    amount: 5.05
    status: "1"
    ctime: _ctime
    mtime: _mtime
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
    insertPayment = (cb) ->
      userDb.insert _payment, _payment._id, (err, res) ->
        _payment._rev = res.rev
        cb()

    async.parallel [
      authUser
      insertPayment
    ], ready


  after (finished) ->
    ## destroy payment
    userDb.destroy(_payment._id, _payment._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/payments/#{_userId}"
      json: true
      headers: cookie: _cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'payment\' type entry in user db', (done) ->
    userDb.get _payment._id, (err, payment) ->
      should.not.exist(err)
      payment.should.eql(_payment)
      done()
