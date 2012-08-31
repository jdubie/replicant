should = require('should')
request = require('request')

config = require('config')
h = require('lib/helpers')


describe 'POST /payments', () ->

  _username = h.hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  ## note: ctime and mtime not necessary for posts (set by replicant)
  _payment =
    _id: 'postpaymentsid'
    type: 'payment'
    name: _username
    user_id: _userId
    event_id: 'eventid'
    card_id: 'cardid'
    status: "1"
    baz: 'bar'
  _cookie = null

  userDb = config.nanoAdmin.db.use(h.getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    config.nano.auth _username, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      _cookie = headers['set-cookie'][0]
      ready()


  after (finished) ->
    ## destroy payment
    userDb.get _payment._id, (err, payment) ->
      should.not.exist(err)
      userDb.destroy(payment._id, payment._rev, finished)

  it 'should POST the payment correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/payments"
      json: _payment
      headers: cookie: _cookie
    request opts, (err, res, payment) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      payment.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      done()
