should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano} = require('config')


describe 'GET /users', () ->

  usersNano = []

  before (ready) ->
    # start webserver
    app = require('../../../app')

    ## get the _correct_ list of users
    db = nano.db.use('lifeswap')
    opts = include_docs: true
    db.view 'lifeswap', 'users', opts, (err, res) ->
      should.not.exist(err)
      usersNano = (row.doc for row in res.rows)
      ready()

  it 'should provide a list of all the correct users', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/users'
      json: true
    request opts, (err, res, users) ->
      should.not.exist(err)
      users.should.eql(usersNano)
      done()
