should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano} = require('config')


describe 'GET /users', () ->

  _users = []

  before (ready) ->
    # start webserver
    app = require('app')

    # create two users
    async.parallel
      user1: createUser(user: _id: 'getusers1')

  after (finished) ->

    # delete both users

  it 'should provide a list of all the correct users', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/users'
      json: true
    request opts, (err, res, users) ->
      should.not.exist(err)
      users.should.eql(usersNano)
      done()
