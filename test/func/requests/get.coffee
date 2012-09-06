should  = require('should')
async   = require('async')
request = require('request')

{nanoAdmin} = require('config')
{hash}      = require('lib/helpers')
{TestUser, TestRequest} = require('lib/test_models')


describe 'yyy GET /requests', () ->

  user1 = new TestUser('getrequestsuser1')
  user2 = new TestUser('getrequestsuser2')
  request1 = new TestRequest('getrequests1', user1)
  request2 = new TestRequest('getrequests2', user2)

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    # start webserver
    app = require('app')
    ## insert users and requests
    async.parallel [
      user1.create
      user2.create
      request1.create
      request2.create
    ], ready

  after (finished) ->
    ## destroy users and requests
    async.parallel [
      user1.destroy
      user2.destroy
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
