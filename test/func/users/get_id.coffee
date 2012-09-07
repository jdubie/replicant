should  = require('should')
async   = require('async')
request = require('request')

{TestUser} = require('lib/test_models')


describe 'yyy GET /users/:id', () ->

  user = new TestUser('get_users_id')

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    user.destroy(finished)

  it 'should get the correct user\'s document', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/users/#{user._id}"
      json: true
    request opts, (err, res, user) ->
      should.not.exist(err)
      user.should.eql(user)
      done()
