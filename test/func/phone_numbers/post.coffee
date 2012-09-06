should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestPhoneNumber} = require('lib/test_models')


describe 'yyy POST /phone_numbers', () ->

  user = new TestUser('post_phone_user')
  phoneNumber = new TestPhoneNumber('post_phone', user)

  userDb = nanoAdmin.db.use(getUserDbName(userId: user._id))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user
    user.create(ready)

  after (finished) ->
    ## destroy user (and thus phone number)
    user.destroy(finished)

  it 'should POST the phone number correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/phone_numbers"
      json: phoneNumber.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, phone) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 201)
      phone.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      for key, val of phone
        phoneNumber[key] = val
      done()

  it 'should have the phone number in the user db', (done) ->
    userDb.get phoneNumber._id, (err, phone) ->
      should.not.exist(err)
      phone.should.eql(phoneNumber.attributes())
      done()
