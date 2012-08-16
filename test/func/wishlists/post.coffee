should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'POST /wishlists', () ->

  _wishlist =
    _id: 'postwishlists'
    type: 'wishlist'
  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    ready()


  after (finished) ->
    mainDb.destroy(_wishlist._id, _wishlist._rev, finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/swaps"
      json: _wishlist
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        _wishlist[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get _wishlist._id, (err, wishlist) ->
      should.not.exist(err)
      wishlist.should.eql(_wishlist)
      done()
