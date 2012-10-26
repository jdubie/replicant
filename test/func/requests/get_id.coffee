should = require('should')
util = require('util')
request = require('request').defaults(jar: false)

{TestUser, TestRequest} = require('lib/test_models')


describe 'GET /requests/:id', () ->

  user = new TestUser('getrequestsidser')
  _request = new TestRequest('getrequestsid', user)

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert request
    _request.create(ready)

  after (finished) ->
    ## destroy request
    _request.destroy(finished)

  it 'should get the correct request', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/requests/#{_request._id}"
      json: true
    request opts, (err, res, requestDoc) ->
      should.not.exist(err)
      requestDoc.should.eql(_request.attributes())
      done()
