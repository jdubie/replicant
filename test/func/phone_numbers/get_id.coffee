should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'GET /phone_numbers/:id', () ->

  ## from the test/toy data
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _phone =
    _id: 'phoneid'
    type: 'phone_number'

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
    ## insert phone
    insertCard = (cb) ->
      userDb.insert _phone, _phone._id, (err, res) ->
        _phone._rev = res.rev
        cb()
    ## in parallel
    async.parallel [
      authUser
      insertCard
    ], (err, res) ->
      ready()


  after (finished) ->
    ## destroy phone
    userDb.destroy(_phone._id, _phone._rev, finished)


  it 'should GET the phone_number', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/phone_numbers/#{_phone._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, phone) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      phone.should.eql(_phone)
      done()