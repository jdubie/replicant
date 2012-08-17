should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'PUT /cards/:id', () ->

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _card =
    _id: 'putcardid'
    type: 'card'
    foo: 'bar'

  cookie = null

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
    insertCard = (callback) ->
      userDb.insert _card, (err, res) ->
        should.not.exist(err)
        _card._rev = res.rev
        callback()

    async.series [
      authUser
      insertCard
    ], ready


  after (finished) ->
    ## destroy card
    userDb.get _card._id, (err, card) ->
      should.not.exist(err)
      userDb.destroy(card._id, card._rev, finished)


  it 'should PUT the card document correctly', (done) ->
    _card.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/cards/#{_card._id}"
      json: _card
      headers: cookie: cookie
    request opts, (err, res, card) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      card.should.have.keys(['_rev', 'mtime'])
      done()
