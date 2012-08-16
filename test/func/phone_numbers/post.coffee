should = require('should')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'POST /phone_numbers', () ->

  _userId = 'user2'
  _password = 'pass2'
  _phone =
    _id: 'postphonenumbersid'
    type: 'phone_number'
    baz: 'bar'

  cookie = null
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    nano.auth _userId, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      ready()


  after (finished) ->
    ## destroy phone
    userDb.get _phone._id, (err, phone) ->
      should.not.exist(err)
      userDb.destroy(phone._id, phone._rev, finished)

  it 'should POST the phone number correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/phone_numbers"
      json: _phone
      headers: cookie: cookie
    request opts, (err, res, phone) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      phone.should.have.keys(['_rev', 'mtime', 'ctime'])
      done()
