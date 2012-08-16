should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin} = require('config')


describe 'DELETE /wishlists/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  ## from toy data
  _userId = 'user2'
  _password = 'pass2'
  _wishlist =
    _id: 'deletewishlist'
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

    async.series [
      authUser
      insertReview
    ], ready


  after (finished) ->
    ## destroy wishlist
    mainDb.get _wishlist._id, (err, wishlist) ->
      should.not.exist(err)
      mainDb.destroy(wishlist._id, wishlist._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/wishlists/#{_wishlist._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'wishlist\' type entry in lifeswap db', (done) ->
    mainDb.get _wishlist._id, (err, wishlist) ->
      should.not.exist(err)
      wishlist.should.eql(_wishlist)
      done()
