should  = require('should')
request = require('request')
async   = require('async')
kue     = require('kue')
debug   = require('debug')('replicants/test/func/refer_email/post')

config  = require('config')
{TestUser, TestReferEmail} = require('lib/test_models')


describe 'POST /refer_emails', () ->

  user = new TestUser('post_refer_emails')
  referEmail = new TestReferEmail('post_refer_email_email', user)
  userDb = config.db.user(user._id)

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    async.series([user.destroy, referEmail.destroy], finished)


  it 'should 400 on bad input', (done) ->
    json = referEmail.attributes()
    verifyField = (field, callback) ->
      value = json[field]
      delete json[field]
      opts =
        method: 'POST'
        url: "http://localhost:3001/refer_emails"
        json: json
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 400)
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property(field)

        json[field] = value
        callback()
    async.map(['_id', 'user_id'], verifyField, done)


  it 'should POST the refer_email correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/refer_emails"
      json: referEmail.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, referEmailDoc) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 201)
      referEmailDoc.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      referEmail[key] = value for key, value of referEmailDoc
      done()


  it 'should actually be there', (done) ->
    userDb.get referEmail._id, (err, referEmailDoc) ->
      should.not.exist(err)
      referEmailDoc.should.eql(referEmail.attributes())
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
