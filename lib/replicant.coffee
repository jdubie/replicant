async = require('async')
request = require('request')
_ = require('underscore')
async = require('async')

debug = require('debug')('lifeswap:replicant')
config = require('../config')
{nano} = config


getUserDbName = ({userId}) ->
  return "users_#{userId}"

replicant = {}

###
  createUser - creates usersDB and replicates ddocs to it also sends notification
  @param userId {string}
  @param callback {function}
###
replicant.createUser = ({userId},callback) ->

  userDdocDbName = 'userddocdb'
  userDdocName = 'userddoc'

  userDbName = getUserDbName({userId})
  nano.db.create userDbName, (err, res) ->
    if err
      console.log(err)
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
  replicateMessages - replicates from one users db to others
  @param src {string} dbname of source database
  @param dst {string} dbname of destination database
###
replicant.replicateMessages
replicant.replicateMessages = ({src, dsts, eventId}, callback) ->
  userDdocName = 'userddoc'
  src = getUserDbName({userId: src})
  dsts = _.map dsts, (userId) -> return getUserDbName({userId})
  opts =
    create_target: true
    query_params: {eventId}
    filter: "#{userDdocName}/msgFilter"
  params = _.map dsts, (dst) ->
    return {src, dst, opts}
  replicateEach = ({src,dst,opts}, cb) ->
    nano.db.replicate(src, dst, opts, cb)
  async.map(params, replicateEach, callback)


###
  getUserIdFromSession - helper that extracts userId from session
  @params headers {object.<string, {string|object}>} http headers object
###
replicant.getUserIdFromSession = ({headers}, callback) ->
  unless headers?.cookie? # will trigger 403
    callback(true)
    return
  opts =
    method: 'get'
    url: "#{config.dbUrl}/_session"
    headers: headers
  request opts, (err, res, body) ->
    userId = JSON.parse(body)?.userCtx?.name
    if userId? then callback(null, {userId})
    else callback(true) # will trigger 403


module.exports = replicant

# shut down SMTP connection
process.on 'SIGINT', () ->
  #debug 'shutting down SMTP connection'
  # @todo close db connection
  process.exit()
