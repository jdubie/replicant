should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'GET /email_addresses/:id', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _email =
    _id: 'emailid'
    type: 'email_address'
    name: _username
    user_id: _userId
    email_address: 'user2@test.com'
    ctime: _ctime
    mtime: _mtime
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))


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
    ## insert email
    insertCard = (cb) ->
      userDb.insert _email, _email._id, (err, res) ->
        _email._rev = res.rev
        cb()
    ## in parallel
    async.parallel [
      authUser
      insertCard
    ], (err, res) ->
      ready()

  after (finished) ->
    ## destroy email
    userDb.destroy(_email._id, _email._rev, finished)

  it 'should GET the email_address', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/email_addresses/#{_email._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, email) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      email.should.eql(_email)
      done()
