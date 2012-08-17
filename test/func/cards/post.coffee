should = require('should')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'POST /cards', () ->

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _card =
    _id: 'postcardsid'
    type: 'card'
    name: _username
    user_id: _userId
    balanced_url: 'balanced1'
    ctime: _ctime
    mtime: _mtime
    baz: 'bar'
  cookie = null

  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    nano.auth _username, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      ready()


  after (finished) ->
    ## destroy card
    userDb.get _card._id, (err, card) ->
      should.not.exist(err)
      userDb.destroy(card._id, card._rev, finished)

  it 'should POST the card correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/cards"
      json: _card
      headers: cookie: cookie
    request opts, (err, res, card) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      card.should.have.keys(['_rev', 'mtime', 'ctime'])
      done()
