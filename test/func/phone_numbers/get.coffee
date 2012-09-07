should = require('should')
async = require('async')
util = require('util')
request = require('request')
config = require('config')
h = require('lib/helpers')

{TestUser, TestPhoneNumber} = require('lib/test_models')


describe 'GET /phone_numbers', () ->

  user1 = new TestUser('get_phone_user1')
  user2 = new TestUser('get_phone_user2')
  constable = new TestUser('get_phone_user_constable', roles: ['constable'])
  phoneNumber1 = new TestPhoneNumber('get_phone1', user1)
  phoneNumber2 = new TestPhoneNumber('get_phone2', user1)
  phoneNumber3 = new TestPhoneNumber('get_phone3', user2)

  before (ready) ->
    app = require('app')
    async.series [
      user1.create
      user2.create
      constable.create
      phoneNumber1.create
      phoneNumber2.create
      phoneNumber3.create
    ], ready

  after (finished) ->
    async.series [
      phoneNumber1.destroy
      phoneNumber2.destroy
      phoneNumber3.destroy
      constable.destroy
      user2.destroy
      user1.destroy
    ], finished

  it 'should GET all phone numbers', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/phone_numbers"
      json: true
      headers: cookie: user1.cookie
    request opts, (err, res, phoneNumbers) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      _phoneNumbersNano = [
        phoneNumber1.attributes()
        phoneNumber2.attributes()
      ]
      phoneNumbers.should.eql(_phoneNumbersNano)
      done()

  it 'should GET all phone number for user2', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/phone_numbers"
      json: true
      headers: cookie: user2.cookie
    request opts, (err, res, phoneNumbers) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      _phoneNumbersNano = [
        phoneNumber3.attributes()
      ]
      phoneNumbers.should.eql(_phoneNumbersNano)
      done()

  it 'should put phone numbers in constable db', (done) ->
    ids = (pn._id for pn in [phoneNumber1, phoneNumber2, phoneNumber3])
    getNumber = (id, cb) -> config.db.constable().get(id, h.nanoCallback2(cb))
    async.map ids, getNumber, (err, res) ->
      should.not.exist(err)
      _phoneNumbersNano = [
        phoneNumber1.attributes()
        phoneNumber2.attributes()
        phoneNumber3.attributes()
      ]
      res.should.eql(_phoneNumbersNano)
      done()

  it 'should allow constable to GET all phone numbers', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/phone_numbers"
      json: true
      headers: cookie: constable.cookie
    request opts, (err, res, phoneNumbers) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      _phoneNumbersNano = [
        phoneNumber1.attributes()
        phoneNumber2.attributes()
        phoneNumber3.attributes()
      ]
      phoneNumbers.should.eql(_phoneNumbersNano)
      done()
