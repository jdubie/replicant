should = require('should')
async = require('async')
request = require('request')

{TestUser, TestEmailAddress} = require('lib/test_models')


describe 'yyy GET /email_addresses', () ->

  user = new TestUser('get_email_user')
  emailAddress1 = new TestEmailAddress('get_email1', user)
  emailAddress2 = new TestEmailAddress('get_email2', user)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and email addresses
    async.series [
      user.create
      emailAddress1.create
      emailAddress2.create
    ], ready

  after (finished) ->
    ## destroy user (destroys emails too)
    user.destroy(finished)

  it 'should GET all emails', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/email_addresses"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, emailAddresses) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      _emailAddressesNano = [
        emailAddress1.attributes()
        emailAddress2.attributes()
      ]
      emailAddresses.should.eql(_emailAddressesNano)
      done()
