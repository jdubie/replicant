should = require('should')
nano = require('nano')('http://tester:tester@localhost:5985')
{signup} = require('../../lib/replicant')

describe 'POST /signup', () ->

  userId = 'testUser'

  before (ready) ->
    signup userId, (err,res) ->
      should.not.exist(err)
      res.should.equal(true)
      ready()

  after (finished) ->
    nano.db.destroy(userId,finished)

  it 'should create user\'s database', (done) ->
    nano.db.list (err, res) ->
      should.not.exist(err)
      res.should.include(userId)
      done()
    
  # @todo assert existence of user data document
  # @todo assert replication of user data document
