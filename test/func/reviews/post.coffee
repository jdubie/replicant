should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'POST /reviews', () ->

  _review =
    _id: 'postreviews'
    type: 'review'
  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    ready()


  after (finished) ->
    mainDb.destroy(_review._id, _review._rev, finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/swaps"
      json: _review
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        _review[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get _review._id, (err, review) ->
      should.not.exist(err)
      review.should.eql(_review)
      done()
