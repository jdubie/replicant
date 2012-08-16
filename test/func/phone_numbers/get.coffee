should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'GET /phone_numbers', () ->

  ## from the test/toy data
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _phones = [
    {
      _id: 'phoneid1'
      type: 'phone_number'
    }
    {
      _id: 'phoneid2'
      type: 'phone_number'
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
      ## insert phone
      insertPhone = (phone, cb) ->
        userDb.insert phone, phone._id, (err, res) ->
          phone._rev = res.rev
          cb()
      insertPhones = (cb) -> async.map(_phones, insertPhone, cb)
      ## in parallel
      async.parallel [
        authUser
        insertPhones
      ], ready


    after (finished) ->
      ## destroy phones
      destroyPhone = (phone, callback) ->
        userDb.destroy(phone._id, phone._rev, callback)
      ## in parallel
      async.map(_phones, destroyPhone, finished)


    it 'should GET all phone numbers', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/phone_numbers"
        json: true
        headers: cookie: cookie
      request opts, (err, res, phones) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        phones.should.eql(_phones)
        done()
