should = require('should')
async = require('async')
util = require('util')
request = require('request').defaults(jar: false)

{TestUser, TestPayment} = require('lib/test_models')
config = require('config')
h = require('lib/helpers')


describe 'GET /payments/:id', () ->

  user = new TestUser('get_payments_id_user')
  payment = new TestPayment('get_payments_id', user)

  before (ready) ->
    app = require('app')
    async.series([user.create, payment.create], ready)

  after (finished) ->
    async.series([payment.destroy, user.destroy], finished)

  it 'should GET the payment', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/payments/#{payment._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, paymentDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      paymentDoc.should.eql(payment.attributes())
      done()
