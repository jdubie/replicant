should = require('should')
nano = require('nano')('http://tester:tester@localhost:5985')
{createUser} = require('../../lib/replicant')

describe '#createUser', () ->

  _userId = 'testuser'

  before (ready) ->

    _createUser = createUser.bind null, {userId: _userId}, (err, res) ->
      should.not.exist(err)
      res.should.have.property('ok', true)
      ready()

    # make sure we delete users's db beforehand
    nano.db.list (err,res) ->
      should.not.exist(err)
      if _userId in res
        nano.db.destroy(_userId, _createUser)
      else _createUser()


  after (finished) ->
    nano.db.destroy(_userId,finished)

  it 'should create user\'s database', (done) ->
    nano.db.list (err, res) ->
      should.not.exist(err)
      res.should.include(_userId)
      done()
    
  # @todo assert existence of user data document
  # @todo assert replication of user data document
  # @todo handle failures, retries?
