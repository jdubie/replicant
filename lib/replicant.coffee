async = require('async')
request = require('request')
_ = require('underscore')
debug = require('debug')('lifeswap:replicant')
nano = require('nano')('http://tester:tester@localhost:5985')
async = require('async')

replicant = {}

# replicant.createUser
replicant.createUser = ({userId},callback) ->

  userDdocDbName = 'userddocdb'
  userDdocName = 'userddoc'

  nano.db.create userId, (err, res) ->
    if err
      callback(err)
    else
      opts =
        doc_ids: [ "_design/#{userDdocName}" ]
      nano.db.replicate(userDdocDbName, userId, opts, callback)

# replicant.createEvent
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


# replicant.getEventUsers
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


# replicant.replicateMessages
replicant.replicateMessages = ({src, dsts, eventId}, callback) ->
  userDdocName = 'userddoc'
  opts =
    create_target: true
    query_params: {eventId}
    filter: "#{userDdocName}/msgFilter"
  params = _.map dsts, (dst) ->
    return {src, dst, opts}
  replicateEach = ({src,dst,opts}, cb) ->
    nano.db.replicate(src, dst, opts, cb)
  async.map(params, replicateEach, callback)


# replicant.getUserIdFromSession
replicant.getUserIdFromSession = ({headers}, callback) ->
  unless headers?.cookie? # will trigger 403
    callback(true)
    return
  opts =
    method: 'get'
    url: 'http://lifeswaptest:5985/_session'
    headers: headers
  request opts, (err, res, body) ->
    userId = JSON.parse(body)?.userCtx?.name
    if userId? then callback(null, {userId})
    else callback(true) # will trigger 403


module.exports = replicant

# shut down SMTP connection
process.on 'SIGINT', () ->
  #debug 'shutting down SMTP connection'
  #smtpTransport.close()
  # TODO close db connection
  process.exit()
