should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl} = require('config')


describe 'PUT /swaps/:id', () ->

  _userId = 'putswapsuser'
  _password = 'sekr1t'
  _swapDoc =
    _id: 'putswap'
    type: 'swap'
    host: _userId
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')

  before (ready) ->
    ## start webserver
    app = require('../../../app')

    ## insert user
    insertUser = (callback) ->
      userDoc =
        _id: "org.couchdb.user:#{_userId}"
        type: 'user'
        name: _userId
        password: _password
        roles: []
      usersDb.insert userDoc, (err, res) ->
        should.not.exist(err)
        callback()

    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()

    ## insert swap
    insertSwap = (callback) ->
      mainDb.insert _swapDoc, (err, res) ->
        should.not.exist(err)
        _swapDoc._rev = res.rev
        callback()

    async.series [
      insertUser
      authUser
      insertSwap
    ], ready


  after (finished) ->
    ## destroy user
    destroyUser = (callback) ->
      couchUser = "org.couchdb.user:#{_userId}"
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        usersDb.destroy(couchUser, userDoc._rev, callback)

    ## destroy swap
    destroySwap = (callback) ->
      mainDb.get _swapDoc._id, (err, swapDoc) ->
        should.not.exist(err)
        mainDb.destroy(swapDoc._id, swapDoc._rev, callback)

    async.parallel([destroyUser, destroySwap], finished)


  it 'should put the swap document correctly', (done) ->
    _swapDoc.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/swaps/#{_swapDoc._id}"
      json: _swapDoc
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.body.should.have.property('id', _swapDoc._id)
      res.statusCode.should.eql(201)
      done()
