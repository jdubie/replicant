should  = require('should')
request = require('request')
async   = require('async')

config  = require('config')
{TestUser, TestEmailAddress} = require('lib/test_models')


describe 'POST /email_addresses', () ->

  user = new TestUser('post_email_user')
  emailAddress = new TestEmailAddress('post_email', user)

  userDb = config.db.user(user._id)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user
    user.create(ready)

  after (finished) ->
    ## destroy user (and thus email address)
    async.series([emailAddress.destroy, user.destroy], finished)


  it 'should 403 on bad input', (done) ->
    verifyField = (field, callback) ->
      json = emailAddress.attributes()
      delete json[field]
      opts =
        method: 'POST'
        url: "http://localhost:3001/email_addresses"
        json: json
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 403)
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property(field)
        callback()
    async.map(['_id', 'user_id'], verifyField, done)

  it 'should POST the email address correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/email_addresses"
      json: emailAddress.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, email) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 201)
      email.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      emailAddress[key] = val for key, val of email
      done()

  it 'should have the email address in the user db', (done) ->
    userDb.get emailAddress._id, (err, email) ->
      should.not.exist(err)
      email.should.eql(emailAddress.attributes())
      done()
