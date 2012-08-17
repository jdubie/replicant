should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'GET /cards/:id', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  cookie = null
  _card =
    _id: 'cardid'
    type: 'card'

  mainDb = nanoAdmin.db.use('lifeswap')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))


  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (cb) ->
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        cb()
    ## insert card
    insertCard = (cb) ->
      userDb.insert _card, _card._id, (err, res) ->
        _card._rev = res.rev
        cb()
    ## in parallel
    async.parallel [
      authUser
      insertCard
    ], (err, res) ->
      ready()


  after (finished) ->
    ## destroy card
    userDb.destroy(_card._id, _card._rev, finished)


  it 'should GET the card', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/cards/#{_card._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, card) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      card.should.eql(_card)
      done()
