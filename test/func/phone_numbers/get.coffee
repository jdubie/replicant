should = require('should')
async = require('async')
util = require('util')
request = require('request')

{TestUser, TestPhoneNumber} = require('lib/test_models')


describe 'yyy GET /phone_numbers', () ->

  user = new TestUser('get_phone_user')
  phoneNumber1 = new TestPhoneNumber('get_phone1', user)
  phoneNumber2 = new TestPhoneNumber('get_phone2', user)


  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and phone numbers
    async.series [
      user.create
      phoneNumber1.create
      phoneNumber2.create
    ], ready

  after (finished) ->
    ## destroy user (destroys phone numbers too)
    async.series [
      phoneNumber1.destroy
      phoneNumber2.destroy
      user.destroy
    ], finished

  it 'should GET all phone numbers', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/phone_numbers"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, phoneNumbers) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      _phoneNumbersNano = [
        phoneNumber1.attributes()
        phoneNumber2.attributes()
      ]
      phoneNumbers.should.eql(_phoneNumbersNano)
      done()
