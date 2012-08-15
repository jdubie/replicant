should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'PUT /email_addresses/:id', () ->

  _userId = 'user2'
  _password = 'pass2'
  _email =
    _id: 'putemailid'
    type: 'email_address'
    foo: 'bar'

  cookie = null

  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert email
    insertEmail = (callback) ->
      userDb.insert _email, (err, res) ->
        should.not.exist(err)
        _email._rev = res.rev
        callback()

    async.series [
      authUser
      insertEmail
    ], ready


  after (finished) ->
    ## destroy email
    userDb.get _email._id, (err, email) ->
      should.not.exist(err)
      userDb.destroy(email._id, email._rev, finished)


  it 'should PUT the email_address correctly', (done) ->
    _email.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/email_addresses/#{_email._id}"
      json: _email
      headers: cookie: cookie
    request opts, (err, res, email) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      email.should.have.keys(['_rev', 'mtime'])
      done()
