should  = require('should')
request = require('request').defaults(jar: false)
async   = require('async')

config  = require('config')
{TestUser, TestPayment} = require('lib/test_models')


describe 'POST /payments', () ->

  user    = new TestUser('post_payments_user')
  payment = new TestPayment('post_payments', user)
  userDb  = config.db.user(user._id)

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    async.series([payment.destroy, user.destroy], finished)


  it 'should 403 on bad input', (done) ->
    verifyField = (field, callback) ->
      json = payment.attributes()
      delete json[field]
      opts =
        method: 'POST'
        url: "http://localhost:3001/payments"
        json: json
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 403)
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property(field)
        callback()
    async.map(['_id', 'user_id'], verifyField, done)


  it 'should POST the payment correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/payments"
      json: payment.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, paymentDoc) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 201)
      paymentDoc.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      payment[key] = value for key, value of paymentDoc
      done()


  it 'should actually be there', (done) ->
    userDb.get payment._id, (err, paymentDoc) ->
      should.not.exist(err)
      paymentDoc.should.eql(payment.attributes())
      done()
