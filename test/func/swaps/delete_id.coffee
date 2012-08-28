should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'DELETE /swaps/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _swap =
    _id: 'deleteswap'
    type: 'swap'
    name: _username
    user_id: _userId
    status: 'pending'
    title: 'Delete this Swap'
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
    app = require('../../../app')
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


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/swaps/#{_swap._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'swap\' type entry in lifeswap db', (done) ->
    mainDb.get _swap._id, (err, swap) ->
      should.not.exist(err)
      swap.should.eql(_swap)
      done()
