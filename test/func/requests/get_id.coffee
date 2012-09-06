should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')
h = require('lib/helpers')


describe 'GET /requests/:id', () ->

  _ctime = _mtime = 12345
  _request =
    _id: 'getrequestid'
    type: 'request'
    name: h.hash('user2@test.com')
    user_id: 'user2_id'
    title: 'GET requests'
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert request
    mainDb.insert _request, _request._id, (err, res) ->
      _request._rev = res.rev
      ready()

  after (finished) ->
    mainDb.destroy(_request._id, _request._rev, finished)

  it 'should get the correct request', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/requests/#{_request._id}"
      json: true
    request opts, (err, res, requestDoc) ->
      should.not.exist(err)
      requestDoc.should.eql(_request)
      done()
