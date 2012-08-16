should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'GET /reviews/:id', () ->

  _review =
    _id: 'getreviewid'
    type: 'review'

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert review
    mainDb.insert _review, _review._id, (err, res) ->
      _review._rev = res.rev
      ready()

  after (finished) ->
    mainDb.destroy(_review._id, _review._rev, finished)

  it 'should get the correct review', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/reviews/#{_review._id}"
      json: true
    request opts, (err, res, review) ->
      should.not.exist(err)
      review.should.eql(_review)
      done()
