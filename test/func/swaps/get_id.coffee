should  = require('should')
async   = require('async')
request = require('request')

{nano} = require('config')
{TestUser, TestSwap} = require('lib/test_models')


describe 'GET /swaps/:id', () ->

  user = new TestUser('getswapiduser')
  swap = new TestSwap('getswapid', user)

  before (ready) ->
    ## start webserver
    app = require('app')
    async.parallel([user.create, swap.create], ready)

  after (finished) ->
    async.parallel([user.destroy, swap.destroy], finished)

  it 'should get the correct swap', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/swaps/#{swap._id}"
      json: true
    request opts, (err, res, _swap) ->
      should.not.exist(err)
      _swap.should.eql(swap.attributes())
      done()
