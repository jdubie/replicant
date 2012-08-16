should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'GET /requests/:id', () ->

  _request =
    _id: 'getrequestid'
    type: 'request'

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
