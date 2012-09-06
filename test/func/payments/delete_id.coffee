should = require('should')
async = require('async')
request = require('request')

config = require('config')
h = require('lib/helpers')
{TestUser, TestPayment} = require('lib/test_models')


describe 'yyyy DELETE /payments/:id', () ->

  user = new TestUser('delete_payments_id_user')
  payment = new TestPayment('delete_payments_id', user)
  userDb = config.nanoAdmin.db.use(h.getUserDbName(userId: user._id))

  before (ready) ->
    app = require('app')
    async.series([user.create, payment.create], ready)

  after (finished) ->
    user.destroy(finished) # destroys payment too

  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/payments/#{payment._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()

  it 'should not delete \'payment\' type entry in user db', (done) ->
    userDb.get payment._id, (err, paymentDoc) ->
      should.not.exist(err)
      paymentDoc.should.eql(payment.attributes())
      done()
