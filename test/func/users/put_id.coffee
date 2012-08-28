should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')


describe 'PUT /users/:id', () ->

  _username = hash('putuser@test.com')
  _userId = 'putuser'
  _password = 'putpass'
  _ctime = _mtime = 12345
  _userDoc =
    _id: _userId
    type: 'user'
    name: _username
    ctime: _ctime
    mtime: _mtime
    foo: 'put bar'
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  couchUser = "org.couchdb.user:#{_username}"

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user
    insertUser = (callback) ->
      async.parallel [
        (cb) ->
          userDoc =
            _id: couchUser
            type: 'user'
            name: _username
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
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## in series
    async.series([insertUser, authUser], ready)

  after (finished) ->
    destroyUser = (callback) ->
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        usersDb.destroy(couchUser, userDoc._rev, callback)
    destroyLifeswapUser = (callback) ->
      mainDb.get _userId, (err, userDoc) ->
        should.not.exist(err)
        mainDb.destroy(_userId, userDoc._rev, callback)
    ## in parallel
    async.parallel([destroyUser, destroyLifeswapUser], finished)


  it 'should put the user\'s document correctly', (done) ->
    _userDoc.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/users/#{_userId}"
      json: _userDoc
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      body.should.have.keys(['_rev', 'mtime'])
      done()
