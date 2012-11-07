should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)
kue     = require('kue')

config     = require('config')
h          = require('lib/helpers')
{TestUser} = require('lib/test_models')

describe 'POST /users', () ->

  user = new TestUser('post_users', hobo: 'foo')

  _userDoc =
    email_address : user.email_address
    password      : user.password
    _id           : user._id
    user_id       : user._id
    type          : 'user'
    name          : user.name
    ctime         : user.ctime
    mtime         : user.mtime
    hobo          : user.hobo   # make sure 'user' doc is just this

  usersDb = config.db._users()
  mainDb  = config.db.main()
  userDb  = config.db.user(user._id)
  couchUser = "org.couchdb.user:#{user.name}"

  describe 'correctness:', () ->

    ##  Start the app
    before (ready) ->
      # start webserver
      app = require('app')
      ready()


    after (finished) ->
      async.parallel [
        user.destroy
        (callback) -> config.jobs.client.flushall(callback)
      ], finished


    it 'should pass back name, roles, user_id, ctime, mtime, _rev', (done) ->
      opts =
        url: 'http://localhost:3001/users'
        method: 'POST'
        json: _userDoc
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        body.should.have.keys(['name', 'roles', 'user_id', 'ctime', 'mtime', '_rev'])
        body.name.should.eql(user.name)
        body.roles.should.eql(user.roles)   # == []
        body.user_id.should.eql(user._id)
        user.ctime = _userDoc.ctime = body.ctime
        user.mtime = _userDoc.mtime = body.mtime
        user._rev  = _userDoc._rev  = body._rev
        res.headers.should.have.property('set-cookie')
        done()

    it 'should create user in _users with name hash(email)', (done) ->
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        userDoc.should.have.property('user_id', user._id)
        done()

    it 'should create a user type document in lifeswap DB', (done) ->
      mainDb.get user._id, (err, userDoc) ->
        should.not.exist(err)
        delete _userDoc.email_address
        delete _userDoc.password
        userDoc.should.eql(_userDoc)
        done()

    it 'should create user database', (done) ->
      config.couch().db.list (err, dbs) ->
        dbs.should.include(h.getUserDbName(userId: user._id))
        done()

    it 'should create email_address type private document', (done) ->
      opts =
        key: 'email_address'
        include_docs: true
      userDb.view 'userddoc', 'docs_by_type', opts, (err, res) ->
        should.not.exist(err)
        res.rows.length.should.eql(1)
        doc = res.rows[0].doc
        doc.should.have.property('type', 'email_address')
        doc.should.have.property('email_address', user.email_address)
        doc.should.have.property('user_id', user._id)
        done()

    it 'should trigger an email to user via redis', (done) ->
      kue.Job.get 1, (err, res) ->
        res.should.have.property('data')
        res.data.should.have.property('emailAddress', user.email_address)
        res.data.should.have.property('user')
        res.data.user.should.have.property('name', user.name)
        done()


    it 'should 400 on bad input', (done) ->
      verifyField = (field, callback) ->
        json = {}
        json[kk] = vv for kk, vv of _userDoc
        value = json[field]
        delete json[field]
        opts =
          url: 'http://localhost:3001/users'
          method: 'POST'
          json: json
          headers: cookie: user.cookie
        request opts, (err, res, body) ->
          should.not.exist(err)
          res.should.have.property('statusCode', 400)
          body.should.have.keys(['error', 'reason'])
          body.reason.should.have.property(field)
          callback()
      async.map(['email_address', '_id'], verifyField, done)


#  it 'should 403 when user is unauthenticated', (done) ->
#    request.post 'http://localhost:3001/users', (err, res, body) ->
#      should.not.exist(err)
#      JSON.parse(body).should.have.property('status', 403)
#      res.statusCode.should.equal(403)
#
#      # assert user database was not created
#      nano.db.list (err, res) ->
#        res.should.not.include(user._id)
#        done()
#
#  it 'should create user data base if they are authenticated', (done) ->
#    opts =
#      url: 'http://localhost:3001/users'
#      headers: cookie: cookie
#    request.post opts, (err, res, body) ->
#      should.not.exist(err)
#      res.statusCode.should.equal(201)
#      res.body = JSON.parse(res.body)
#      res.body.should.have.property('ok', true)
#
#      # assert user database was created
#      nano.db.list (err, res) ->
#        userDbName = h.getUserDbName({userId: user._id})
#        res.should.include(userDbName)
#        done()

#   @todo be able to start/stop couch from tests
#  it 'should 500 when it fails to create db', (done) ->
