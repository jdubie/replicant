should  = require('should')
request = require('request')
async   = require('async')
h       = require('lib/helpers')
config  = require('config')
debug   = require('debug')('replicants/test/func/refer_email/post')
kue     = require('kue')

{TestUser, TestReferEmail} = require('lib/test_models')


describe 'zzz POST /refer_emails', () ->

  user = new TestUser('post_refer_emails')
  referEmail = new TestReferEmail('post_refer_email_email', user)

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    async.series([user.destroy, referEmail.destroy], finished)

  it 'should POST the refer_email correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/refer_emails"
      json: referEmail.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, referEmailDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      referEmailDoc.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      done()

  it 'should add notification', (done) ->
    kue.Job.get 1, (err, job) ->
      should.not.exist(err)
      job.should.have.property('type', 'notification.refer_email.create')
      job.should.have.property('data')
      job.data.should.have.property('refer_email')
      job.data.refer_email.should.have.property('personal_message', referEmail.personal_message)
      job.data.refer_email.should.have.property('request_id', referEmail.requestId)
      done()
