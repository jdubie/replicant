should = require('should')
async = require('async')
request = require('request')

{TestUser, TestPayment} = require('lib/test_models')
config = require('config')
h = require('lib/helpers')


describe 'yyyy PUT /payments/:id', () ->

  newAmount = 444
  
  user = new TestUser('put_payments_user')
  payment = new TestPayment('put_payments', user)
  userDb = config.nanoAdmin.db.use("users_#{user._id}")

  before (ready) ->
    app = require('app')
    async.series([user.create, payment.create], ready)

  after (finished) ->
    user.destroy(finished)

  it 'we should rething this one', () ->

    # shouldn't be able to change amount or status?

    #  it 'should PUT the payment successfully', (done) ->
    #    payment.amount.should.not.eql(newAmount)
    #    payment.amount = newAmount
    #    opts =
    #      method: 'PUT'
    #      url: "http://localhost:3001/payments/#{payment._id}"
    #      json: payment.attributes()
    #      headers: cookie: user.cookie
    #    request opts, (err, res, payment) ->
    #      should.not.exist(err)
    #      res.statusCode.should.eql(201)
    #      payment.should.have.keys(['_rev', 'mtime'])
    #      done()
    #
    #  it 'should have actually have change doc', (done) ->
    #    userDb.get payment._id, (err, paymentDoc) ->
    #      should.not.exist(err)
    #      paymentDoc.amount.should.equal(newAmount)
    #      done()
