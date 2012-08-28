should = require('should')
util = require('util')
request = require('request')

{jobs, nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')
kue = require('kue')

describe 'POST /swaps', () ->

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _swap =
    _id: 'postswaps'
    type: 'swap'
    name: _username
    user_id: _userId
    status: 'pending'
    title: 'Posted Swap'
    zipcode: '94305'
    industry: 'Agriculture'
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    nano.auth _username, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      jobs.client.flushall(ready)

  after (finished) ->
    mainDb.destroy _swap._id, _swap._rev, (err, res) ->
      return finished(err) if err?
      jobs.client.flushall(finished)

  it 'should POST the swap correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/swaps"
      json: _swap
      headers: {cookie}
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        _swap[key] = val
      done()

  it 'should added notification', (done) ->
    kue.Job.get 1, (err, job) ->
      should.not.exist(err)
      job.should.have.property('type', 'notification.swap.create')
      job.should.have.property('data')
      done()
