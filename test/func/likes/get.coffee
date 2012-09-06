should = require('should')
util = require('util')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')


describe 'yyyy GET /likes', () ->

  ctime = mtime = 12345
  _likes = [
    {
      _id: 'getlikes1'
      type: 'like'
      name: '-hash2-'
      user_id: 'user2'
      swap_id: 'swap1'
      ctime: ctime
      mtime: mtime
      foo: 'bar'
    }
    {
      _id: 'getlikes2'
      type: 'like'
      name: '-hash1-'
      user_id: 'user1'
      swap_id: 'swap1'
      ctime: ctime
      mtime: mtime
      foo: 'bar'
    }
  ]

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    # start webserver
    app = require('app')
    ## insert like
    insertLike = (like, cb) ->
      mainDb.insert like, like._id, (err, res) ->
        like._rev = res.rev
        cb()
    async.map(_likes, insertLike, ready)

  after (finished) ->
    destroyLike = (like, cb) ->
      mainDb.destroy(like._id, like._rev, cb)
    async.map(_likes, destroyLike, finished)

  it 'should provide a list of all the correct likes', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/likes'
      json: true
    request opts, (err, res, likes) ->
      should.not.exist(err)
      likes.should.eql(_likes)
      done()
