should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'DELETE /email_addresses/:id', () ->

  ## simple test - for now should just 403 (forbidden)
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  cookie = null
  _email =
    _id: 'deleteemailid'
    type: 'email_address'

  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert email
    insertEmail = (cb) ->
      userDb.insert _email, _email._id, (err, res) ->
        _email._rev = res.rev
        cb()

    async.parallel [
      authUser
      insertEmail
    ], ready


  after (finished) ->
    ## destroy email
    userDb.destroy(_email._id, _email._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/email_addresses/#{_userId}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'email_address\' type entry in user db', (done) ->
    userDb.get _email._id, (err, email) ->
      should.not.exist(err)
      email.should.eql(_email)
      done()
