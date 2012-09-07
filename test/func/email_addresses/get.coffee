should = require('should')
async = require('async')
request = require('request')
config = require('config')
h = require('lib/helpers')

{TestUser, TestEmailAddress} = require('lib/test_models')


describe 'GET /email_addresses', () ->

  user = new TestUser('get_email_user')
  constable = new TestUser('get_email_user_constable', roles: ['constable'])
  emailAddress1 = new TestEmailAddress('get_email1', user)
  emailAddress2 = new TestEmailAddress('get_email2', user)

  before (ready) ->
    app = require('app')
    async.series [
      user.create
      constable.create
      emailAddress1.create
      emailAddress2.create
    ], ready

  after (finished) ->
    async.series [
      emailAddress1.destroy
      emailAddress2.destroy
      constable.destroy
      user.destroy
    ], finished

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

  it 'should put email address in constable db', (done) ->
    ids = (pn._id for pn in [emailAddress1, emailAddress2])
    getEmail = (id, cb) -> config.db.constable().get(id, h.nanoCallback2(cb))
    async.map ids, getEmail, (err, res) ->
      should.not.exist(err)
      _emailAddresses = [
        emailAddress1.attributes()
        emailAddress2.attributes()
      ]
      res.should.eql(_emailAddresses)
      done()

  it 'should allow constable to get all emails as well', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/email_addresses"
      json: true
      headers: cookie: constable.cookie
    request opts, (err, res, emailAddresses) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      _emailAddressesNano = [
        emailAddress1.attributes()
        emailAddress2.attributes()
      ]
      emailAddresses.should.eql(_emailAddressesNano)
      done()
