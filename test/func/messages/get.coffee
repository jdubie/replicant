should = require('should')
async = require('async')
_ = require('underscore')
util = require('util')
request = require('request')
debug = require('debug')('replicant/test/func/phone_numbers/delete')

{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'zzzz GET /messages', () ->

  ## from the test/toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  cookie = null
  _ctime = _mtime = 12345
  _messages = null

  mainDb = nanoAdmin.db.use('lifeswap')
  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))

  ## these could be general functions (helpers?)
  #insertDocUser = (userId, doc, cb) ->
  #  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))
  #  userDb.insert doc, doc._id, (err, res) ->
  #    if not err then doc._rev = res.rev
  #    cb()
  #destroyDocUser = (userId, doc, cb) ->
  #  userDb = nanoAdmin.db.use(getUserDbName(userId: _userId))
  #  userDb.destroy doc._id, doc._rev, (err, res) ->
  #    if err then console.error err
  #    cb(err, res)

  getAllMessages = (callback) ->
    userDb.view 'userddoc', 'docs_by_type', key: 'message', include_docs: true, (err, body) ->
      msgs = _.map body.rows, (row) -> row.doc
      callback(err, msgs)

  getAllReadDocs = (callback) ->
    userDb.view 'userddoc', 'docs_by_type', key: 'read', include_docs: true, (err, body) ->
      read_docs = _.map body.rows, (row) -> row.doc
      callback(err, read_docs)

  authUser = (callback) ->
    nano.auth _username, _password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      callback()


  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    insertMessage = (msg, cb) -> insertDocUser(_userId, msg, cb)
    ## in parallel
    async.parallel {getAllMessages, getAllReadDocs, authUser}, (err, res) ->
      should.not.exist(err)

      # mark read messages read
      _messages = res.getAllMessages
      readDocs = res.getAllReadDocs

      for message in _messages
        message.read = false

      for message in _messages
        for readDoc in readDocs
          if message._id is readDoc.message_id
            message.read = true
      ready()

  it 'should GET all messages w/ correct read status', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/messages"
      json: true
      headers: {cookie}
    request opts, (err, res, messages) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      messages.should.eql(_messages)
      done()
