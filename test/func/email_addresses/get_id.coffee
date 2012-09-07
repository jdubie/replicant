should = require('should')
async = require('async')
util = require('util')
request = require('request')

{TestUser, TestEmailAddress} = require('lib/test_models')


describe 'yyy GET /email_addresses/:id', () ->

  user = new TestUser('get_email_id_user')
  emailAddress = new TestEmailAddress('get_email_id', user)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and email address
    async.series([user.create, emailAddress.create], ready)

  after (finished) ->
    ## destroy email address and user
    async.series([emailAddress.destroy, user.destroy], finished)

  it 'should GET the email_address', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/email_addresses/#{emailAddress._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, email) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      email.should.eql(emailAddress.attributes())
      done()
