should = require('should')
{nano} = require('../../config')
{createUser} = require('../../lib/replicant')

{getUserDbName} = require('../../../lifeswap/shared/helpers')

describe '#createUser', () ->

  _userId = 'testuser'
  userDbName = getUserDbName({userId: _userId})

  before (ready) ->

    _createUser = createUser.bind null, {userId: _userId}, (err, res) ->
      should.not.exist(err)
      res.should.have.property('ok', true)
      ready()

    # make sure we delete users's db beforehand
    nano.db.list (err,res) ->
      should.not.exist(err)
      if userDbName in res
        nano.db.destroy(userDbName, _createUser)
      else _createUser()


  after (finished) ->
    nano.db.destroy(userDbName, finished)

  it 'should create user\'s database', (done) ->
    nano.db.list (err, res) ->
      should.not.exist(err)
      res.should.include(userDbName)
      done()
    
  # @todo assert existence of user data document
  # @todo assert replication of user data document
  # @todo handle failures, retries?
