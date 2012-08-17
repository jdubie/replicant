should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'GET /cards', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _cards = [
    {
      _id: 'getcards1'
      type: 'card'
      name: _username
      user_id: _userId
      balanced_url: 'balanced1'
      ctime: _ctime
      mtime: _mtime
    }
    {
      _id: 'getcards2'
      type: 'card'
      name: _username
      user_id: _userId
      balanced_url: 'balanced2'
      ctime: _ctime
      mtime: _mtime
    }
  ]
  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  describe 'correctness:', () ->

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
      insertCard = (card, cb) ->
        userDb.insert card, card._id, (err, res) ->
          card._rev = res.rev
          cb()
      insertCards = (cb) -> async.map(_cards, insertCard, cb)
      ## in parallel
      async.parallel [
        authUser
        insertCards
      ], ready


    after (finished) ->
      ## destroy cards
      destroyCard = (card, callback) ->
        userDb.destroy(card._id, card._rev, callback)
      ## in parallel
      async.map(_cards, destroyCard, finished)


    it 'should GET all cards', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/cards"
        json: true
        headers: cookie: cookie
      request opts, (err, res, cards) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        cards.should.eql(_cards)
        done()
