should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl} = require('config')


describe 'PUT /wishlists/:id', () ->

  ## from toy data
  _userId = 'user2'
  _password = 'pass2'
  _wishlist =
    _id: 'putwishlistsid'
    type: 'wishlist'
    name: _userId
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert wishlist
    insertReview = (callback) ->
      mainDb.insert _wishlist, (err, res) ->
        should.not.exist(err)
        _wishlist._rev = res.rev
        callback()
    ## in parallel
    async.series [
      authUser
      insertReview
    ], ready


  after (finished) ->
    ## destroy wishlist
    mainDb.destroy(_wishlist._id, _wishlist._rev, finished)


  it 'should return _rev and mtime', (done) ->
    _wishlist.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/wishlists/#{_wishlist._id}"
      json: _wishlist
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        _wishlist[key] = val
      done()

  it 'should modify the document in the DB', (done) ->
    mainDb.get _wishlist._id, (err, wishlist) ->
      should.not.exist(err)
      wishlist.should.eql(_wishlist)
      done()
