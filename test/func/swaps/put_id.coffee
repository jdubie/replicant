should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')


describe 'PUT /swaps/:id', () ->

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _swap =
    _id: 'putswap'
    type: 'swap'
    name: _username
    user_id: _userId
    status: 'pending'
    title: 'Put a Swap'
    zipcode: '94305'
    industry: 'Agriculture'
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')
  usersDb = nanoAdmin.db.use('_users')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert swap
    insertSwap = (callback) ->
      mainDb.insert _swap, (err, res) ->
        should.not.exist(err)
        _swap._rev = res.rev
        callback()
    ## in parallel
    async.parallel([authUser, insertSwap], ready)

  after (finished) ->
    ## destroy swap
    mainDb.destroy(_swap._id, _swap._rev, finished)


  it 'should put the swap document correctly', (done) ->
    _swap.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/swaps/#{_swap._id}"
      json: _swap
      headers: {cookie}
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        _swap[key] = val
      done()
