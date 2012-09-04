should  = require('should')
request = require('request')
h       = require('lib/helpers')
config  = require('config')
debug   = require('debug')('replicants/test/func/refer_email/post')

describe 'zzz POST /refer_emails', () ->

  _username = h.hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _requestId = 'request1'
  _email_address = 'test@thelifeswap.com'
  _ctime = _mtime = 12345
  _referEmail =
    _id: 'post_refer_email_id'
    type: 'refer_email'
    name: _username
    user_id: _userId
    request_id: _requestId
    email_address: _email_address
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
      ready()

  after (finished) ->
    ## destroy refer_email
    userDb.get _referEmail._id, (err, referEmail) ->
      should.not.exist(err)
      userDb.destroy(_referEmail._id, referEmail._rev, finished)

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
