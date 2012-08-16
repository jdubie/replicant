should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'GET /email_addresses/:id', () ->

  ## from the test/toy data
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _email =
    _id: 'emailid'
    type: 'email_address'

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))


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
      res.statusCode.should.eql(200)
      email.should.eql(_email)
      done()
