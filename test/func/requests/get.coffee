should  = require('should')
async   = require('async')
request = require('request')

{TestUser, TestRequest} = require('lib/test_models')


describe 'GET /requests', () ->

  user1 = new TestUser('getrequestsuser1')
  user2 = new TestUser('getrequestsuser2')
  request1 = new TestRequest('getrequests1', user1)
  request2 = new TestRequest('getrequests2', user2)

  before (ready) ->
    # start webserver
    app = require('app')
    ## insert requests
    async.parallel [
      request1.create
      request2.create
    ], ready

  after (finished) ->
    ## destroy requests
    async.parallel [
      request1.destroy
      request2.destroy
    ], finished

  it 'should provide a list of all the correct requests', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/requests'
      json: true
    request opts, (err, res, requests) ->
      should.not.exist(err)
      requestsNano = [request1.attributes(), request2.attributes()]
      requests.should.eql(requestsNano)
      done()
