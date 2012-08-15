should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'GET /email_addresses', () ->

  ## from the test/toy data
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _emails = [
    {
      _id: 'emailid1'
      type: 'email_address'
    }
    {
      _id: 'emailid2'
      type: 'email_address'
    }
  ]

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')
      ## authenticate user
      authUser = (cb) ->
        nano.auth _userId, _password, (err, body, headers) ->
          should.not.exist(err)
          should.exist(headers and headers['set-cookie'])
          cookie = headers['set-cookie'][0]
          cb()
      ## insert email
      insertEmail = (email, cb) ->
        userDb.insert email, email._id, (err, res) ->
          email._rev = res.rev
          cb()
      insertEmails = (cb) -> async.map(_emails, insertEmail, cb)
      ## in parallel
      async.parallel [
        authUser
        insertEmails
      ], ready


    after (finished) ->
      ## destroy emails
      destroyEmail = (email, callback) ->
        userDb.destroy(email._id, email._rev, callback)
      ## in parallel
      async.map(_emails, destroyEmail, finished)


    it 'should GET all emails', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/email_addresses"
        json: true
        headers: cookie: cookie
      request opts, (err, res, emails) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        emails.should.eql(_emails)
        done()
