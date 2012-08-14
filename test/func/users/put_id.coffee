should = require('should')
async = require('async')
util = require('util')
request = require('request')
{nanoAdmin} = require('../../../config')
{nano} = require('../../../config')
{dbUrl} = require('../../../config')


describe 'PUT /users/:id', () ->

  _userId = 'someuser'
  _password = 'sekr1t'
  _userDoc =
    _id: _userId
    type: 'user'
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')

  before (ready) ->
    ## start webserver
    app = require('../../../app')

    ## insert user
    insertUser = (callback) ->



      async.parallel [
        (cb) ->
          userDoc =
            _id: "org.couchdb.user:#{_userId}"
            type: 'user'
            name: _userId
            password: _password
            roles: []
          usersDb.insert userDoc, (err, res) ->
            should.not.exist(err)
            cb()
        (cb) ->
          mainDb.insert _userDoc, _userId, (err, res) ->
            should.not.exist(err)
            _userDoc._rev = res.rev
            cb()
      ], callback

    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()

    async.series([insertUser, authUser], ready)


  after (finished) ->
    destroyUser = (callback) ->
      couchUser = "org.couchdb.user:#{_userId}"
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        usersDb.destroy(couchUser, userDoc._rev, callback)
    destroyLifeswapUser = (callback) ->
      mainDb.get _userId, (err, userDoc) ->
        should.not.exist(err)
        mainDb.destroy(_userId, userDoc._rev, callback)
    async.parallel [
      destroyUser
      destroyLifeswapUser
    ], finished


  it 'should put the user\'s document correctly', (done) ->
    _userDoc.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/users/#{_userId}"
      json: _userDoc
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.body.should.have.property('id', _userId)
      res.statusCode.should.eql(201)
      done()
