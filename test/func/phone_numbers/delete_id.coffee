should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestPhoneNumber} = require('lib/test_models')


describe 'DELETE /phone_numbers/:id', () ->

  user = new TestUser('delete_phone_id_user')
  phoneNumber = new TestPhoneNumber('delete_phone_id', user)

  userDb = nanoAdmin.db.use(getUserDbName(userId: user._id))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and phone number
    async.series([user.create, phoneNumber.create], ready)

  after (finished) ->
    ## destroy phone number and user
    async.series([phoneNumber.destroy, user.destroy], finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/phone_numbers/#{phoneNumber._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'phone_number\' type entry in user db', (done) ->
    userDb.get phoneNumber._id, (err, phone) ->
      should.not.exist(err)
      phone.should.eql(phoneNumber.attributes())
      done()
