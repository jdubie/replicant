async = require('async')
request = require('request')
_ = require('underscore')
async = require('async')
debug = require('debug')('replicant:lib')
{nano} = require('config')
{getUserDbName} = require('lib/helpers')


replicant = {}

###
  createUser - creates usersDB and replicates ddocs to it also sends notification
  @param userId {string}
  @param callback {function}
###
replicant.createUser = ({userId},callback) ->

  userDdocDbName = 'userddocdb'
  userDdocName = 'userddoc'

  security =
    admins:
      names: []
      roles: []
    members:
      names: [userId]
      roles: []

  userDbName = getUserDbName({userId})
  nano.db.create userDbName, (err, res) ->
    if err
      debug err
      callback(err)
    else
      userdb = nano.db.use(userDbName)
      userdb.insert security, '_security', (err, res) ->
        if err
          debug err
          callback(err)
        else
          opts =
            doc_ids: [ "_design/#{userDdocName}" ]
          nano.db.replicate(userDdocDbName, userDbName, opts, callback)

###
  createEvent - creates event -> [users] mapping and writes initial events docs to users db
  @param swapId {string}
  @param userId {string}
  @param callback {function}
###
replicant.createEvent = ({swapId, userId}, callback) ->
  getGuest = (_callback) ->
    _callback(null, userId) # @todo replace with getting this from cookies
  getHosts = (_callback) ->
    db = nano.db.use('lifeswap')
    db.get swapId, (err, swapDoc) ->
      _callback(err, [swapDoc.host]) # @todo swapDoc.host should will be array in future
  createMapping = (users, _callback) ->
    users.push(userId) # @todo this logic may change
    mapper = nano.db.use('mapper')
    mapper.insert {users}, (err, res) ->
      eventId = res.id
      ok = true
      _callback(err, {eventId, users, ok})

  async.waterfall [
    (next) -> getGuest(next)
    (result, next) -> getHosts(next)
    (result, next) -> createMapping(result, next)
  ], callback


###
  getEventUsers
  @param eventId {string}
###
replicant.getEventUsers = ({eventId}, callback) ->
  mapper = nano.db.use('mapper')
  mapper.get eventId, (err, eventDoc) ->
    if err
      if err.error is 'not_found'
        callback({status: 404, reason: "No such event"})
      else
        callback({status: 500, reason: "Internal Server Error"})
    else
      callback(null, {ok: true, status: 200, users: eventDoc.users})


###
  replicate - replicates from one users db to others
  @param src {string} dbname of source database
  @param dst {string} dbname of destination database
###
replicant.replicate = ({src, dsts, eventId}, callback) ->
  userDdocName = 'userddoc'
  src = getUserDbName({userId: src})
  dsts = _.map dsts, (userId) -> return getUserDbName({userId})
  opts =
    create_target: true
    query_params: {eventId}
    filter: "#{userDdocName}/eventFilter"
  params = _.map dsts, (dst) ->
    return {src, dst, opts}
  replicateEach = ({src,dst,opts}, cb) ->
    nano.db.replicate(src, dst, opts, cb)
  async.map(params, replicateEach, callback)

  # send emails
  #replicant.sendNotifications({dsts, eventId})

  #replicant.sendNotifications = ({dsts, eventId}) ->
  #_.each dsts, (dst) ->
  #  getDbName

replicant.auth = ({username, password}, callback) ->
  nano.auth username, password, (err, body, headers) ->
    if err or not headers
      callback(err or not headers)
    else
      callback(null, headers['set-cookie'])


replicant.getUsers = (callback) ->
  db = nano.db.use('lifeswap')
  opts = include_docs: true
  db.view 'lifeswap', 'users', opts, (err, res) ->
    debug err, res
    if not err then users = (row.doc for row in res.rows)
    callback(err, users)


replicant.getSwaps = (callback) ->
  db = nano.db.use('lifeswap')
  opts = include_docs: true
  db.view 'lifeswap', 'swaps', opts, (err, res) ->
    debug err, res
    if not err then swaps = (row.doc for row in res.rows)
    callback(err, swaps)


module.exports = replicant

# shut down SMTP connection
process.on 'SIGINT', () ->
  #debug 'shutting down SMTP connection'
  # @todo close db connection
  process.exit()
