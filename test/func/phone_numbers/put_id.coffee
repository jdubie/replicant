should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestPhoneNumber} = require('lib/test_models')


describe 'yyy PUT /phone_numbers/:id', () ->

  user = new TestUser('put_phone_user')
  phoneNumber = new TestPhoneNumber('put_phone', user, foo: 'bar')

  userDb = nanoAdmin.db.use(getUserDbName(userId: user._id))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and phone number
    async.series([user.create, phoneNumber.create], ready)


  after (finished) ->
    ## destroy phone number, then user
    async.series([phoneNumber.destroy, user.destroy], finished)


  it 'should PUT the phone_number correctly', (done) ->
    phoneNumber.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/phone_numbers/#{phoneNumber._id}"
      json: phoneNumber.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, phone) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      phone.should.have.keys(['_rev', 'mtime'])
      for key, val of phone
        phoneNumber[key] = val
      done()

  it 'should put the phone number in the user db', (done) ->
    userDb.get phoneNumber._id, (err, phone) ->
      should.not.exist(err)
      phone.should.eql(phoneNumber.attributes())
      done()
