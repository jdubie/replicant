should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'GET /cards', () ->

  ## from the test/toy data
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _cards = [
    {
      _id: 'cardid1'
      type: 'card'
    }
    {
      _id: 'cardid2'
      type: 'card'
    }
  ]

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  describe 'correctness:', () ->

    before (ready) ->
      ## start webserver
      app = require('app')
      ## authenticate user
      authUser = (cb) ->
        nano.auth _userId, _password, (err, body, headers) ->
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
