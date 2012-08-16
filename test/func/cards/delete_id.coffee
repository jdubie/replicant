should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName} = require('lib/helpers')


describe 'DELETE /cards/:id', () ->

  ## simple test - for now should just 403 (forbidden)
  _userId = 'user2'
  _password = 'pass2'
  cookie = null
  _card =
    _id: 'deletecardid'
    type: 'card'

  mainDb = nanoAdmin.db.use('lifeswap')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _userId, _password, (err, body, headers) ->
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
