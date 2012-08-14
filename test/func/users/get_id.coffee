should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'GET /users/:id', () ->

  _userId = 'someuser'
  _userDoc =
    _id: _userId
    type: 'user'
    foo: 'bar'

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')

    ## insert user
    mainDb.insert _userDoc, _userId, (err, res) ->
      should.not.exist(err)
      _userDoc._rev = res.rev
      ready()


  after (finished) ->
    ## delete the user
    mainDb.destroy _userId, _userDoc._rev, (err, res) ->
      should.not.exist(err)
      finished()


  it 'should get the correct user\'s document', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/users/#{_userId}"
      json: true
    request opts, (err, res, userDoc) ->
      should.not.exist(err)
      userDoc.should.eql(_userDoc)
      done()
