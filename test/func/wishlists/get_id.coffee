should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'GET /wishlists/:id', () ->

  _wishlist =
    _id: 'getwishlistid'
    type: 'wishlist'

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert wishlist
    mainDb.insert _wishlist, _wishlist._id, (err, res) ->
      _wishlist._rev = res.rev
      ready()

  after (finished) ->
    mainDb.destroy(_wishlist._id, _wishlist._rev, finished)

  it 'should get the correct wishlist', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/wishlists/#{_wishlist._id}"
      json: true
    request opts, (err, res, wishlist) ->
      should.not.exist(err)
      wishlist.should.eql(_wishlist)
      done()
