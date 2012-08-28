should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'DELETE /cards/:id', () ->

  ## simple test - for now should just 403 (forbidden)
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _card =
    _id: 'deletecardid'
    type: 'card'
    name: _username
    user_id: _userId
    balanced_url: 'balanced'
    ctime: _ctime
    mtime: _mtime
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert card
    insertCard = (cb) ->
      userDb.insert _card, _card._id, (err, res) ->
        _card._rev = res.rev
        cb()

    async.parallel [
      authUser
      insertCard
    ], ready


  after (finished) ->
    ## destroy card
    userDb.destroy(_card._id, _card._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/cards/#{_userId}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'card\' type entry in user db', (done) ->
    userDb.get _card._id, (err, card) ->
      should.not.exist(err)
      card.should.eql(_card)
      done()
