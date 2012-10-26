should  = require('should')
request = require('request').defaults(jar: false)
async   = require('async')
kue     = require('kue')
debug   = require('debug')('replicant/test/func/likes/post')
config  = require('config')

{TestUser, TestLike} = require('lib/test_models')


describe 'POST /likes', () ->

  user = new TestUser('user_post_likes')
  like = new TestLike('post_likes', user)

  mainDb = config.db.main()

  before (ready) ->
    app = require('app')
    async.parallel [
      user.create
      (cb) -> config.jobs.client.flushall(cb)
    ], ready


  after (finished) ->
    async.parallel [
      like.destroy
      user.destroy
      (cb) -> config.jobs.client.flushall(cb)
    ], finished

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
