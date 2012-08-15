should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin, dbUrl} = require('config')


describe 'DELETE /swaps/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  _userId = 'deleteswapsuser'
  _password = 'sekr1t'
  _swapDoc =
    _id: 'deleteswap'
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
    ## in parallel
    async.parallel([destroyUser, destroySwap], finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/swaps/#{_swapDoc._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'swap\' type entry in lifeswap db', (done) ->
    mainDb.get _swapDoc._id, (err, swapDoc) ->
      should.not.exist(err)
      swapDoc.should.eql(_swapDoc)
      done()
