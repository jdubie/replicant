should = require('should')
util = require('util')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')


describe 'GET /wishlists', () ->

  _wishlists = [
    {
      _id: 'getwishlists1'
      type: 'wishlist'
    }
    {
      _id: 'getwishlists2'
      type: 'wishlist'
    }
  ]

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    # start webserver
    app = require('app')
    ## insert wishlist
    insertWishlist = (wishlist, cb) ->
      mainDb.insert wishlist, wishlist._id, (err, res) ->
        wishlist._rev = res.rev
        cb()
    async.map(_wishlists, insertWishlist, ready)

  after (finished) ->
    destroyWishlist = (wishlist, cb) ->
      mainDb.destroy(wishlist._id, wishlist._rev, cb)
    async.map(_wishlists, destroyWishlist, finished)

  it 'should provide a list of all the correct wishlists', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/wishlists'
      json: true
    request opts, (err, res, wishlists) ->
      should.not.exist(err)
      wishlists.should.eql(_wishlists)
      done()
