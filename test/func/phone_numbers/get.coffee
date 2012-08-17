should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'GET /phone_numbers', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  cookie = null
  _phoneNumbersNano = []

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')
      ## authenticate user
      authUser = (cb) ->
        nano.auth _username, _password, (err, body, headers) ->
          should.not.exist(err)
          should.exist(headers and headers['set-cookie'])
          cookie = headers['set-cookie'][0]
          cb()
      ## get phone numbers
      getPhoneNumbers = (cb) ->
        opts =
          key: 'phone_number'
          include_docs: true
        userDb.view 'userddoc', 'docs_by_type', opts, (err, res) ->
          should.not.exist(err)
          _phoneNumbersNano = (row.doc for row in res?.rows)
          cb()
      ## in parallel
      async.parallel [
        authUser
        getPhoneNumbers
      ], ready

    it 'should GET all phone numbers', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/phone_numbers"
        json: true
        headers: cookie: cookie
      request opts, (err, res, phoneNumbers) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        phoneNumbers.should.eql(_phoneNumbersNano)
        done()
