should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'PUT /phone_numbers/:id', () ->

  _userId = 'user2'
  _password = 'pass2'
  _phone =
    _id: 'putphoneid'
    type: 'phone_number'
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
    ## insert phone
    insertPhone = (callback) ->
      userDb.insert _phone, (err, res) ->
        should.not.exist(err)
        _phone._rev = res.rev
        callback()

    async.series [
      authUser
      insertPhone
    ], ready


  after (finished) ->
    ## destroy phone
    userDb.get _phone._id, (err, phone) ->
      should.not.exist(err)
      userDb.destroy(phone._id, phone._rev, finished)


  it 'should PUT the phone_number correctly', (done) ->
    _phone.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/phone_numbers/#{_phone._id}"
      json: _phone
      headers: cookie: cookie
    request opts, (err, res, phone) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      phone.should.have.keys(['_rev', 'mtime'])
      done()
