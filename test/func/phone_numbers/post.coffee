should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

config  = require('config')
{TestUser, TestPhoneNumber} = require('lib/test_models')


describe 'POST /phone_numbers', () ->

  user = new TestUser('post_phone_user')
  phoneNumber = new TestPhoneNumber('post_phone', user)

  userDb = config.db.user(user._id)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user
    user.create(ready)

  after (finished) ->
    ## destroy user (and thus phone number)
    async.series([phoneNumber.destroy, user.destroy], finished)


  it 'should 403 on bad input', (done) ->
    verifyField = (field, callback) ->
      json = phoneNumber.attributes()
      delete json[field]
      opts =
        method: 'POST'
        url: "http://localhost:3001/phone_numbers"
        json: json
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 403)
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property(field)
        callback()
    async.map(['_id', 'user_id'], verifyField, done)


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
      phoneNumber[key] = val for key, val of phone
      done()

  it 'should have the phone number in the user db', (done) ->
    userDb.get phoneNumber._id, (err, phone) ->
      should.not.exist(err)
      phone.should.eql(phoneNumber.attributes())
      done()
