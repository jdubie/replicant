should  = require('should')
async   = require('async')
request = require('request')
kue = require('kue')

config = require('config')
{TestUser, TestSwap} = require('lib/test_models')

describe 'POST /swaps', () ->

  user = new TestUser('postswapsuser')
  swap = new TestSwap('postswap', user)


  mainDb = config.nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    async.parallel [
      user.create
      (cb) -> config.jobs.client.flushall(cb)
    ], ready

  after (finished) ->
    async.parallel [
      user.destroy
      swap.destroy
      (cb) -> config.jobs.client.flushall(cb)
    ], finished


  it 'should POST the swap correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/swaps"
      json: swap.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        swap[key] = val
      done()

  it 'should have the swap in the DB', (done) ->
    mainDb.get swap._id, (err, _swap) ->
      should.not.exist(err)
      _swap.should.eql(swap.attributes())
      done()

  it 'should add notification', (done) ->
    kue.Job.get 1, (err, job) ->
      should.not.exist(err)
      job.should.have.property('type', 'notification.swap.create')
      job.should.have.property('data')
      done()
