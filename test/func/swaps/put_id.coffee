should = require('should')
async = require('async')
request = require('request')

{TestUser, TestSwap} = require('lib/test_models')


describe 'PUT /swaps/:id', () ->

  user = new TestUser('putswapsiduser')
  swap = new TestSwap('putswapsid', user, foo: 'bar')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and swap
    async.parallel([user.create, swap.create], ready)

  after (finished) ->
    ## destroy user and swap
    async.parallel([user.destroy, swap.destroy], finished)

  it 'should put the swap document correctly', (done) ->
    swap.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/swaps/#{swap._id}"
      json: swap.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        swap[key] = val
      done()
