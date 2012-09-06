should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')
{getUserDbName} = require('lib/helpers')
{TestUser, TestEmailAddress} = require('lib/test_models')


describe 'yyy DELETE /email_addresses/:id', () ->

  user = new TestUser('delete_email_id_user')
  emailAddress = new TestEmailAddress('delete_email_id', user)

  userDb = nanoAdmin.db.use(getUserDbName(userId: user._id))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and email address
    async.series([user.create, emailAddress.create], ready)

  after (finished) ->
    ## destroy user (destroys email address as well)
    user.destroy(finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/email_addresses/#{emailAddress._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'email_address\' type entry in user db', (done) ->
    userDb.get emailAddress._id, (err, email) ->
      should.not.exist(err)
      email.should.eql(emailAddress.attributes())
      done()
