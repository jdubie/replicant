should = require('should')
async = require('async')
util = require('util')
request = require('request')
{nano} = require('../../../config')


describe 'GET /user', () ->

  usersNano = []

  ###
    Make sure that user's db doesn't exist
  ###
  before (ready) ->
    # start webserver
    app = require('../../../app')

    db = nano.db.use('lifeswap')
    opts = include_docs: true
    db.view 'lifeswap', 'users', opts, (err, res) ->
      should.not.exist(err)
      usersNano = (row.doc for row in res.rows)
      ready()

  it 'should provide a list of all the correct users', (done) ->
    request.get 'http://localhost:3001/users', (err, res, users) ->
      should.not.exist(err)
      users = JSON.parse(users)
      users.should.eql(usersNano)
      done()
