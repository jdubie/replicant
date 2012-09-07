should = require('should')
util = require('util')
request = require('request')
async = require('async')

{TestUser, TestLike} = require('lib/test_models')
{jobs, nanoAdmin} = require('config')
kue = require('kue')
debug = require('debug')('replicant/test/func/likes/post')


describe 'yyy POST /likes', () ->

  user = new TestUser('user_post_likes')
  like = new TestLike('post_likes', user)

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    async.parallel([like.destroy, user.destroy], finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/likes"
      json: like.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        like[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get like._id, (err, likeDoc) ->
      should.not.exist(err)
      debug 'like.attributes()', like.attributes()
      debug 'likeDoc', likeDoc
      likeDoc.should.eql(like.attributes())
      done()

  it 'should add notification', (done) ->
    kue.Job.get 1, (err, job) ->
      should.not.exist(err)
      job.should.have.property('type', 'notification.like.create')
      job.should.have.property('data')
      job.data.should.have.property('like')
      job.data.like.should.have.property('user_id', like.user_id)
      job.data.like.should.have.property('swap_id', like.swap_id)
      done()
