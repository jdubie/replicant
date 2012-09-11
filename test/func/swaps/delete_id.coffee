should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin} = require('config')
{hash} = require('lib/helpers')
{TestUser, TestSwap} = require('lib/test_models')


describe 'DELETE /swaps/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  user = new TestUser('deleteswapuser')
  swap = new TestSwap('deleteswap', user)

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and swap
    async.parallel([user.create, swap.create], ready)

  after (finished) ->
    ## destroy user and swap
    async.parallel([user.destroy, swap.destroy], finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/swaps/#{swap._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'swap\' type entry in lifeswap db', (done) ->
    mainDb.get swap._id, (err, _swap) ->
      should.not.exist(err)
      _swap.should.eql(swap.attributes())
      done()
