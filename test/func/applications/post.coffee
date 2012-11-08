should  = require('should')
request = require('request').defaults(jar: false)
async   = require('async')
kue     = require('kue')
debug   = require('debug')('replicant/test/func/applications/post')
config  = require('config')

{TestUser, TestApplication} = require('lib/test_models')


describe 'POST /applications', () ->

  user = new TestUser('post_applications_user')
  application = new TestApplication('post_applications', user)

  mainDb = config.db.main()

  before (ready) ->
    app = require('app')
    async.parallel [
      user.create
      (cb) -> config.jobs.client.flushall(cb)
    ], ready


  after (finished) ->
    async.parallel [
      application.destroy
      user.destroy
      (cb) -> config.jobs.client.flushall(cb)
    ], finished

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/applications"
      json: application.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        application[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get application._id, (err, applicationDoc) ->
      should.not.exist(err)
      debug 'application.attributes()', application.attributes()
      debug 'applicationDoc', applicationDoc
      applicationDoc.should.eql(application.attributes())
      done()

  it 'should add notification', (done) ->
    kue.Job.get 1, (err, job) ->
      should.not.exist(err)
      job.should.have.property('type', 'notification.application.create')
      job.should.have.property('data')
      job.data.should.have.property('application')
      job.data.application.should.have.property('user_id', application.user_id)
      job.data.application.should.have.property('swap_id', application.swap_id)
      done()
