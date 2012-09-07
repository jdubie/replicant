should = require('should')
async = require('async')
request = require('request')

{TestUser, TestPayment} = require('lib/test_models')
config = require('config')
h = require('lib/helpers')


describe 'yyy PUT /payments/:id', () ->
  
  user = new TestUser('put_payments_user')
  payment = new TestPayment('put_payments', user)
  userDb = config.nanoAdmin.db.use("users_#{user._id}")

  before (ready) ->
    app = require('app')
    async.series([user.create, payment.create], ready)

  after (finished) ->
    user.destroy(finished)

  it 'should fail on put', (done) ->
    oldAmount = payment.amount
    newAmount = 444
    payment.amount.should.not.eql(newAmount)
    payment.amount = newAmount
    opts =
      method: 'PUT'
      url: "http://localhost:3001/payments/#{payment._id}"
      json: payment.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, payment) ->
      should.not.exist(err)
      res.statusCode.should.eql(403)
      done()
    payment.amount = oldAmount

  it 'should have not actually have changed the doc', (done) ->
    userDb.get payment._id, (err, paymentDoc) ->
      should.not.exist(err)
      paymentDoc.should.eql(payment.attributes())
      done()
