should  = require('should')
async   = require('async')
util    = require('util')
request = require('request')
kue     = require('kue')

{nanoAdmin, jobs} = require('config')
{hash} = require('lib/helpers')

#{getUserDbName} = require('../../../lifeswap/shared/helpers')
getUserDbName = ({userId}) -> return "users_#{userId}"

describe 'POST /users', () ->

  _email = 'newuser@gmail.com'
  _username = hash(_email)
  _password = 'sekr1t'
  _userId = '1234567890'
  _userDbName = getUserDbName(userId: _userId)
  _ctime = _mtime = 12345
  _userDoc =
    email_address: _email
    password: _password
    _id: _userId
    type: 'user'
    name: _username
    ctime: _ctime
    mtime: _mtime
    hobo: 'foo'   # make sure 'user' doc is just this
  cookie = null

  usersDb = nanoAdmin.db.use('_users')
  mainDb = nanoAdmin.db.use('lifeswap')
  userDb = nanoAdmin.db.use(_userDbName)
  couchUser = "org.couchdb.user:#{_username}"

  describe 'correctness:', () ->

    ##  Start the app
    before (ready) ->
      # start webserver
      app = require('app')
      ready()


    after (finished) ->
      destroyUser = (callback) ->
        usersDb.get couchUser, (err, userDoc) ->
          should.not.exist(err)
          usersDb.destroy(couchUser, userDoc._rev, callback)
      destroyLifeswapUser = (callback) ->
        mainDb.get _userId, (err, userDoc) ->
          should.not.exist(err)
          mainDb.destroy(_userId, userDoc._rev, callback)
      destroyUserDb = (callback) ->
        nanoAdmin.db.list (err, dbs) ->
          dbs.should.include(_userDbName)
          nanoAdmin.db.destroy(_userDbName, callback)
      flushRedis = (callback) -> jobs.client.flushall(callback)

      async.parallel [
        destroyUser           # destroy _users entry
        destroyLifeswapUser   # destroy 'user' in Lifeswap
        destroyUserDb         # destory users_... database
        flushRedis            # flush the information in redis
      ], finished


    it 'should pass back name, roles, user_id, ctime, mtime, _rev', (done) ->
      opts =
        url: 'http://localhost:3001/users'
        method: 'POST'
        json: _userDoc
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(201)
        body.should.have.keys(['name', 'roles', 'user_id', 'ctime', 'mtime', '_rev'])
        body.name.should.eql(_username)
        body.roles.should.eql([])
        body.user_id.should.eql(_userId)
        _userDoc.ctime = body.ctime
        _userDoc.mtime = body.mtime
        _userDoc._rev = body._rev
        res.headers.should.have.property('set-cookie')
        done()

    it 'should create user in _users with name hash(email)', (done) ->
      usersDb.get couchUser, (err, userDoc) ->
        should.not.exist(err)
        userDoc.should.have.property('user_id', _userId)
        done()

    it 'should create a user type document in lifeswap DB', (done) ->
      mainDb.get _userId, (err, userDoc) ->
        should.not.exist(err)
        delete _userDoc.email_address
        delete _userDoc.password
        userDoc.should.eql(_userDoc)
        done()

    it 'should create user database', (done) ->
      nanoAdmin.db.list (err, dbs) ->
        dbs.should.include(_userDbName)
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
        doc.should.have.property('email_address', _email)
        doc.should.have.property('user_id', _userId)
        done()

    it 'should trigger an email to user via redis', (done) ->
      kue.Job.get 1, (err, res) ->
        res.should.have.property('data')
        res.data.should.have.property('emailAddress', _email)
        res.data.should.have.property('user')
        res.data.user.should.have.property('name', _username)
        done()


#  it 'should 403 when user is unauthenticated', (done) ->
#    request.post 'http://localhost:3001/users', (err, res, body) ->
#      should.not.exist(err)
#      JSON.parse(body).should.have.property('status', 403)
#      res.statusCode.should.equal(403)
#
#      # assert user database was not created
#      nano.db.list (err, res) ->
#        res.should.not.include(_userId)
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
#        userDbName = getUserDbName({userId: _userId})
#        res.should.include(userDbName)
#        done()

#   @todo be able to start/stop couch from tests
#  it 'should 500 when it fails to create db', (done) ->
