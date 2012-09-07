should = require('should')
async = require('async')
util = require('util')
request = require('request')
config = require('config')
h = require('lib/helpers')

{TestUser, TestPhoneNumber} = require('lib/test_models')


describe 'yyy GET /phone_numbers', () ->

  user = new TestUser('get_phone_user')
  constable = new TestUser('get_phone_user_constable', roles: ['constable'])
  phoneNumber1 = new TestPhoneNumber('get_phone1', user)
  phoneNumber2 = new TestPhoneNumber('get_phone2', user)

  before (ready) ->
    app = require('app')
    async.series [
      user.create
      constable.create
      phoneNumber1.create
      phoneNumber2.create
    ], ready

  after (finished) ->
    async.series [
      phoneNumber1.destroy
      phoneNumber2.destroy
      constable.destroy
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

  it 'should put phone numbers in constable db', (done) ->
    ids = (pn._id for pn in [phoneNumber1, phoneNumber2])
    getNumber = (id, cb) -> config.db.constable().get(id, h.nanoCallback2(cb))
    async.map ids, getNumber, (err, res) ->
      should.not.exist(err)
      _phoneNumbersNano = [
        phoneNumber1.attributes()
        phoneNumber2.attributes()
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
      ]
      phoneNumbers.should.eql(_phoneNumbersNano)
      done()
