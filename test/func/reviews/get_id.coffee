should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'GET /reviews/:id', () ->

  _ctime = _mtime = 12345
  _review =
    _id: 'getreviewid'
    type: 'review'
    name: hash('user2@test.com')
    user_id: 'user2_id'
    review_type: 'swap'
    reviewee_id: 'user1_id'
    swap_id: 'swap1'
    rating: 1
    review: "NOT a buttery swap."
    ctime: _ctime
    mtime: _mtime
    baz: 'bag'

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
