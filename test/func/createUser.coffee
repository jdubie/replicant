should = require('should')
util = require('util')
request = require('request')
nano = require('nano')('http://tester:tester@localhost:5985')
{signup} = require('../../lib/replicant')

describe 'POST /user', () ->

  user = 'user1'
  password = 'pass1'
  app = null
  cookie = null

  ###
    Make sure that user's db doesn't exist
  ###
  before (ready) ->
    # start webserver
    app = require('../../app')
    nano.auth user, password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      ready()


  afterEach (finished) ->
    nano.db.list (err, res) ->
      if user in res
        nano.db.destroy(user,finished)
      else finished()

  it 'should 403 when user is unauthenticated', (done) ->
    request.post 'http://localhost:3000/user', (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.equal(403)
      body.should.equal('User must be logged in')

      # assert user database was not created
      nano.db.list (err, res) ->
        res.should.not.include(user)
        done()

  it 'should create user data base if they are authenticated', (done) ->
    opts =
      url: 'http://localhost:3000/user'
      headers: cookie: cookie
    request.post opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.equal(200)
      res.body = JSON.parse(res.body)
      res.body.should.have.property('ok', true)

      # assert user database was created
      nano.db.list (err, res) ->
        res.should.include(user)
        done()

  # @todo be able to start/stop couch from tests
  #it 'should 500 when it fails to create db', (done) ->

