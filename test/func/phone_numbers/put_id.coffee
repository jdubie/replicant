should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'PUT /phone_numbers/:id', () ->

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _phone =
    _id: 'putphoneid'
    type: 'phone_number'
    name: _username
    user_id: _userId
    phone_number: 5552097765
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'

  cookie = null

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
