should  = require('should')
request = require('request')
h       = require('lib/helpers')
config  = require('config')
debug   = require('debug')('replicants/test/func/refer_email/post')
kue     = require('kue')

{TestUser} = require('lib/test_models')

describe 'yyyy POST /refer_emails', () ->

  user = new TestUser('post_refer_emails')

  _password = 'pass2'
  _requestId = 'request1'
  _email_address = 'test@thelifeswap.com'
  _personal_message = 'hi im a personal message'
  _ctime = _mtime = 12345
  _referEmail =
    _id: 'post_refer_email_id'
    type: 'refer_email'
    name: user.name
    user_id: user._id
    request_id: _requestId
    email_address: _email_address
    personal_message: _personal_message
    ctime: _ctime
    mtime: _mtime

  userDb = config.nanoAdmin.db.use(h.getUserDbName(userId: user._id))

  before (ready) ->
    # start webserver
    app = require('app')
    user.create(ready)

  after (finished) ->
    ## destroy refer_email
    userDb.get _referEmail._id, (err, referEmail) ->
      should.not.exist(err)
      userDb.destroy _referEmail._id, referEmail._rev, (err) ->
        should.not.exist(err)
        user.destroy(finished)

  it 'should POST the refer_email correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/refer_emails"
      json: _referEmail
      headers: cookie: user.cookie
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
