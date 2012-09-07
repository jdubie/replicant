should = require('should')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestEmailAddress} = require('lib/test_models')


describe 'yyy PUT /email_addresses/:id', () ->

  user = new TestUser('put_email_user')
  emailAddress = new TestEmailAddress('put_email', user, foo: 'bar')

  userDb = nanoAdmin.db.use(getUserDbName(userId: user._id))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and email address
    async.series([user.create, emailAddress.create], ready)

  after (finished) ->
    ## destroy user (and thus email address)
    async.series([emailAddress.destroy, user.destroy], finished)

  it 'should PUT the email_address correctly', (done) ->
    emailAddress.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/email_addresses/#{emailAddress._id}"
      json: emailAddress.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, email) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 201)
      email.should.have.keys(['_rev', 'mtime'])
      for key, val of email
        emailAddress[key] = val
      done()

  it 'should put the email address in the user db', (done) ->
    userDb.get emailAddress._id, (err, email) ->
      should.not.exist(err)
      email.should.eql(emailAddress.attributes())
      done()
