should = require('should')
request = require('request')
async = require('async')

{TestUser, TestPayment} = require('lib/test_models')
config = require('config')
h = require('lib/helpers')


describe 'yyy POST /payments', () ->

  user = new TestUser('post_payments_user')
  payment = new TestPayment('post_payments', user)

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    async.series([payment.destroy, user.destroy], finished)

  it 'should POST the payment correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/payments"
      json: payment.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, payment) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      payment.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      done()
