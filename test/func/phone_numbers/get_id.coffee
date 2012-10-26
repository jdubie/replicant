should = require('should')
async = require('async')
util = require('util')
request = require('request').defaults(jar: false)

{TestUser, TestPhoneNumber} = require('lib/test_models')


describe 'GET /phone_numbers/:id', () ->

  user = new TestUser('get_phone_id_user')
  phoneNumber = new TestPhoneNumber('get_phone_id', user)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and phone number
    async.series([user.create, phoneNumber.create], ready)

  after (finished) ->
    ## destroy phone number and user
    async.series([phoneNumber.destroy, user.destroy], finished)

  it 'should GET the phone_number', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/phone_numbers/#{phoneNumber._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, phone) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      phone.should.eql(phoneNumber.attributes())
      done()
