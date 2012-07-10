should = require('should')
request = require('request')
nano = require('nano')('http://lifeswaptest:5985')
{getUserIdFromSession} = require('../../lib/replicant')

describe '#getUserIdFromSession', () ->

  cookie = null
  user = 'user1' # @todo create random user to avoid sessions carrying over
                 # from previous tests
  password = 'pass1'

  before (ready) ->
    nano.auth user, password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      ready()

  it 'should return userid with a good cookie', (done) ->
    getUserIdFromSession headers: {cookie}, (err, res) ->
      should.not.exist(err)
      res.should.have.property('userId', user)
      done()
    
   it 'should return an error with empty cookie', (done) ->
     getUserIdFromSession headers: cookie: '', (err) ->
       err.should.equal(true)
       done()

   it 'should return an error with undefined cookie', (done) ->
     getUserIdFromSession headers: {}, (err) ->
       err.should.equal(true)
       done()
