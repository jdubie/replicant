should = require('should')
util = require('util')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'GET /reviews', () ->

  _ctime = _mtime = 12345
  _reviewsNano = []

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    # start webserver
    app = require('app')
    ## get reviews
    opts =
      key: 'review'
      include_docs: true
    mainDb.view 'lifeswap', 'docs_by_type', opts, (err, res) ->
      _reviewsNano = (row.doc for row in res.rows)
      ready()

  it 'should provide a list of all the correct reviews', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/reviews'
      json: true
    request opts, (err, res, reviews) ->
      should.not.exist(err)
      reviews.should.eql(_reviewsNano)
      done()
