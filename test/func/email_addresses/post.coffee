should = require('should')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'POST /email_addresses', () ->

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _email =
    _id: 'postemailaddressesid'
    type: 'email_address'
    name: _username
    user_id: _userId
    email_address: 'user2@test.com'
    ctime: _ctime
    mtime: _mtime
    baz: 'bar'
  cookie = null

  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    nano.auth _username, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      ready()


  after (finished) ->
    ## destroy email
    userDb.get _email._id, (err, email) ->
      should.not.exist(err)
      userDb.destroy(email._id, email._rev, finished)

  it 'should POST the email address correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/email_addresses"
      json: _email
      headers: cookie: cookie
    request opts, (err, res, email) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      email.should.have.keys(['_rev', 'mtime', 'ctime'])
      done()
