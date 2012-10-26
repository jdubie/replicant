should = require('should')
async = require('async')
request = require('request').defaults(jar: false)

config = require('config')
h = require('lib/helpers')
{TestPayment, TestUser} = require('lib/test_models')


describe 'GET /payments', () ->

  user = new TestUser('get_payments_user')
  payments = ['get_payments_1', 'get_payments_2', 'get_payments_3']
  payments = (new TestPayment(id, user) for id in payments)

  describe 'correctness:', () ->

    before (ready) ->
      app = require('app')
      create = (payment, callback) -> payment.create(callback)
      async.series [
        user.create
        (callback) -> async.map(payments, create, callback)
      ], ready

    after (finished) ->
      destroy = (payment, callback) -> payment.destroy(callback)
      async.series [
        (callback) -> async.map(payments, destroy, callback)
        user.destroy
      ], finished

    it 'should GET all payments', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/payments"
        json: true
        headers: cookie: user.cookie
      request opts, (err, res, paymentDocs) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        paymentDocs.should.eql((p.attributes() for p in payments))
        done()
