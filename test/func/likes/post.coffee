should = require('should')
util = require('util')
request = require('request')

{jobs, nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')
kue = require('kue')
debug = require('debug')('replicant/test/func/likes/post')


describe 'POST /likes', () ->

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  ctime = mtime = 12345
  _like =
    _id: 'postlikes'
    type: 'like'
    name: _username
    user_id: 'user2'
    swap_id: 'swap1'
    ctime: ctime
    mtime: mtime
    foo: 'bar'
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')

    ## authenticate user
    nano.auth _username, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      jobs.client.flushall(ready)

  after (finished) ->
    mainDb.destroy _like._id, _like._rev, (err) ->
      return finished(err) if err
      jobs.client.flushall(finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/likes"
      json: _like
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        _like[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get _like._id, (err, like) ->
      should.not.exist(err)
      like.should.eql(_like)
      done()

  it 'should add notification', (done) ->
    kue.Job.get 1, (err, job) ->
      should.not.exist(err)
      job.should.have.property('type', 'notification.like.create')
      job.should.have.property('data')
      job.data.should.have.property('like')
      job.data.like.should.have.property('user_id', _like.user_id)
      job.data.like.should.have.property('swap_id', _like.swap_id)
      done()
