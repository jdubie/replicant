should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'GET /users/:id', () ->

  someUser = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## get one of the users
    opts =
      key: 'user'
      include_docs: true
    mainDb.view 'lifeswap', 'docs_by_type', opts, (err, res) ->
      should.not.exist(err)
      someUser = res.rows?[0]?.doc
      ready()


  it 'should get the correct user\'s document', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/users/#{someUser._id}"
      json: true
    request opts, (err, res, user) ->
      should.not.exist(err)
      user.should.eql(someUser)
      done()
