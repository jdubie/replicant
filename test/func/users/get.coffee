should  = require('should')
async   = require('async')
request = require('request')

{TestUser} = require('lib/test_models')


describe 'yyy GET /users', () ->

  user1 = new TestUser('get_users_1')
  user2 = new TestUser('get_users_2')

  before (ready) ->
    # start webserver
    app = require('app')
    async.parallel([user1.create, user2.create], ready)

  after (finished) ->
    async.parallel([user1.destroy, user2.destroy], finished)

  it 'should provide a list of all the correct users', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/users'
      json: true
    request opts, (err, res, users) ->
      should.not.exist(err)
      users.should.eql([ user1.attributes(), user2.attributes() ])
      done()
