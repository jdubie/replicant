should = require('should')
request = require('request')
{nano} = require('config')
{getEmailForUser, getUserIdFromSession} = require('lib/helpers')

describe 'helpers', () ->

  describe '#getEmailForUser', () ->
    it 'should get the email address for a user', (done) ->
      getEmailForUser {userId: 'user1'}, (err,res) ->
        should.not.exist(err)
        res.should.equal 'user1@test.com'
        done()

    it 'should return undefined when no email addresses', (done) ->
      getEmailForUser {userId: 'user2'}, (err,res) ->
        should.not.exist(err)
        should.not.exist(res)
        done()


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
