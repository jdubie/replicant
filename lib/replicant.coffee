async = require('async')
request = require('request')
_ = require('underscore')
debug = require('debug')('lifeswap:replicant')
nano = require('nano')('http://tester:tester@localhost:5985')
async = require('async')

replicant = {}

replicant.signup = ({userId},callback) ->

  # Filter function for user DBs
  msgFilter = (doc, req) ->
    if doc.eventId isnt req.query.eventId
      return false
    else
      return true

  # Thread view for user DBs (all messages for an event)
  threadView =
    map: (doc) ->
      if doc.type is 'message'
        value =
          subject: doc.subject
          message: doc.message
          author: doc.author
        key = [doc.eventId, doc.created]
        emit(key, value)

  # Thread view for user DBs (all events)
  threadsView =
    map: (doc) ->
      if doc.type is 'event'
        emit(null, null)

  nano.db.create userId, (err, res) ->
    if err
      callback(err)
    else
      userdb = nano.db.use(userId)
      ddoc =
        _id: "_design/#{userId}"
        filters:
          msgFilter: msgFilter.toString()
        views:
          thread:
            map: threadView.map.toString()
          threads:
            map: threadsView.map.toString()
      userdb.insert(ddoc, callback)


replicant.swapEvent = ({swapId, userId}, callback) ->
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


replicant.swapEventUsers = ({eventId}, callback) ->
  mapper = nano.db.use('mapper')
  mapper.get eventId, (err, eventDoc) ->
    if err
      if err.error is 'not_found'
        callback({status: 404, reason: "No such event"})
      else
        callback({status: 500, reason: "Internal Server Error"})
    else
      callback(null, {ok: true, status: 200, users: eventDoc.users})

replicant.replicate = ({src, dsts, eventId}, callback) ->
  opts =
    create_target: true
    query_params: {eventId}
    # TODO: create this filter in the src's ddoc
    filter: "#{src}/msgFilter"
  params = _.map dsts, (dst) ->
    return {src, dst, opts}
  replicateEach = ({src,dst,opts}, cb) ->
    nano.db.replicate(src, dst, opts, cb)
  async.map(params, replicateEach, callback)

replicant.getUserIdFromSession = ({headers}, callback) ->
  console.log(headers)
  unless headers?.cookie? # will trigger 403
    console.log('no headers.cookie')
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
