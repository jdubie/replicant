should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestEmailAddress} = require('lib/test_models')


describe 'yyy POST /email_addresses', () ->

  user = new TestUser('post_email_user')
  emailAddress = new TestEmailAddress('post_email', user)

  userDb = nanoAdmin.db.use(getUserDbName(userId: user._id))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user
    user.create(ready)

  after (finished) ->
    ## destroy user (and thus email address)
    user.destroy(finished)

  it 'should POST the email address correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/email_addresses"
      json: emailAddress.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, email) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      email.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      for key, val of email
        emailAddress[key] = val
      done()

  it 'should have the email address in the user db', (done) ->
    userDb.get emailAddress._id, (err, email) ->
      should.not.exist(err)
      email.should.eql(emailAddress.attributes())
      done()
