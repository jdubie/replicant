should = require('should')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')


describe 'POST /reviews', () ->

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _review =
    _id: 'postreviews'
    type: 'review'
    name: _username
    user_id: _userId
    review_type: 'swap'
    reviewee_id: 'user1_id'
    swap_id: 'swap1'
    rating: 1
    review: "NOT a buttery swap."
    ctime: _ctime
    mtime: _mtime
    baz: 'bag'
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    nano.auth _username, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      ready()

  after (finished) ->
    mainDb.destroy(_review._id, _review._rev, finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/reviews"
      json: _review
      headers: {cookie}
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
