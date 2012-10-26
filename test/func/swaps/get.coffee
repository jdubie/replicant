should  = require('should')
request = require('request').defaults(jar: false)
async   = require('async')

{TestUser, TestSwap} = require('lib/test_models')


describe 'GET /swaps', () ->

  swapsNano = []
  user1 = new TestUser('getswapsuser1')
  user2 = new TestUser('getswapsuser2')
  swap1 = new TestSwap('getswaps1', user1)
  swap2 = new TestSwap('getswaps2', user2)

  before (ready) ->
    # start webserver
    app = require('app')
    ## insert users and swaps
    async.parallel [
      user1.create
      user2.create
      swap1.create
      swap2.create
    ], ready

  after (finished) ->
    async.parallel [
      user1.destroy
      user2.destroy
      swap1.destroy
      swap2.destroy
    ], finished

  it 'should provide a list of all the correct swaps', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/swaps'
      json: true
    request opts, (err, res, swaps) ->
      should.not.exist(err)
      swapsNano = [swap1.attributes(), swap2.attributes()]
      swaps.should.eql(swapsNano)
      done()
