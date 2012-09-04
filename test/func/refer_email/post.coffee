should  = require('should')
request = require('request')
h       = require('lib/helpers')
config  = require('config')
debug   = require('debug')('replicants/test/func/refer_email/post')
kue     = require('kue')

describe 'POST /refer_emails', () ->

  _username = h.hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _requestId = 'request1'
  _email_address = 'test@thelifeswap.com'
  _personal_message = 'hi im a personal message'
  _ctime = _mtime = 12345
  _referEmail =
    _id: 'post_refer_email_id'
    type: 'refer_email'
    name: _username
    user_id: _userId
    request_id: _requestId
    email_address: _email_address
    personal_message: _personal_message
    ctime: _ctime
    mtime: _mtime
  cookie = null

  userDb = config.nanoAdmin.db.use(h.getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    config.nano.auth _username, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      config.jobs.client.flushall(ready)

  after (finished) ->
    ## destroy refer_email
    userDb.get _referEmail._id, (err, referEmail) ->
      should.not.exist(err)
      userDb.destroy _referEmail._id, referEmail._rev, (err) ->
        should.not.exist(err)
        config.jobs.client.flushall(finished)

  it 'should POST the refer_email correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/refer_emails"
      json: _referEmail
      headers: cookie: cookie
    request opts, (err, res, referEmail) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      referEmail.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      done()

  it 'should add notification', (done) ->
    kue.Job.get 1, (err, job) ->
      should.not.exist(err)
      job.should.have.property('type', 'notification.refer_email.create')
      job.should.have.property('data')
      job.data.should.have.property('refer_email')
      job.data.refer_email.should.have.property('personal_message', _personal_message)
      job.data.refer_email.should.have.property('request_id', _requestId)
      done()
