should = require('should')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'POST /cards', () ->

  _userId = 'user2'
  _password = 'pass2'
  _card =
    _id: 'postcardsid'
    type: 'card'
    baz: 'bar'

  cookie = null
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    nano.auth _userId, _password, (err, body, headers) ->
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