should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'DELETE /phone_numbers/:id', () ->

  ## simple test - for now should just 403 (forbidden)
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _phone =
    _id: 'deletephoneid'
    type: 'phone_number'

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
    insertPhone = (cb) ->
      userDb.insert _phone, _phone._id, (err, res) ->
        _phone._rev = res.rev
        cb()

    async.parallel [
      authUser
      insertPhone
    ], ready


  after (finished) ->
    ## destroy phone
    userDb.destroy(_phone._id, _phone._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/phone_numbers/#{_userId}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'phone_number\' type entry in user db', (done) ->
    userDb.get _phone._id, (err, phone) ->
      should.not.exist(err)
      phone.should.eql(_phone)
      done()
