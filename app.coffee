express = require('express')
_ = require('underscore')
debug = require('debug')('replicant:app')

{getUserIdFromSession} = require('./lib/replicant')
{createUser} = require('./lib/replicant')
{createEvent} = require('./lib/replicant')
{getEventUsers} = require('./lib/replicant')
{replicateMessages} = require('./lib/replicant')
{listen} = require('./lib/adminNotifications')

app = express.createServer()
app.use(express.bodyParser())

###
  POST /users
  CreateUser
    This creates a user database and preliminary doc after user signups on client
    using user.signup and session.login on client
    @param session {cookie} authenicates user
    @method POST
    @url /users

    userId = getIdFromSession()
    POST / userId # creates users database
    POST /userId {firstname, lastname, ...}
    replicate /userId /lifeswap filter(public)
###
app.post '/users', (req, res) ->
  debug 'POST /users'
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'}, 403)
    else
      userId = r.userId
      createUser {userId}, (e,r) ->
        if e
          res.json({status: 500, reason: "Internal Server Error: #{e}", 500})
        else
          res.json(r, 201)


###
  POST /events
  CreateEvent
    This service creates a swapEventId and initializes involed users 
    @param swapId {string} swap for which swapEvent is being created
    @param session {cookie} authenicates user
    @method POST

    hosts = GET /lifeswap/swapId
    guest = getIdFromSession()
    swapEventId = POST /mapper {guest,hosts}
    return swapEventId
###
app.post  '/events', (req, res) ->
  swapId = req.body.swapId
  debug "POST /events"
  debug "   swapId: #{swapId}"
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'}, 403)
    else
      userId = r.userId
      createEvent {swapId, userId}, (e, r) ->
        if e then res.json({status: 500, reason: "Internal Server Error: #{e}"}, 500)
        else
          res.json(r, 201)


# GET /events/members
app.get '/events/members', (req, res) ->
  # TODO: do we want it as a GET?
  eventId = req.query.eventId
  debug "GET /events/members"
  debug "   eventId: #{eventId}"
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'}, 403)
    else
      userId = r.userId
      getEventUsers {eventId}, (e, r) ->
        # there should only be responses, no errors
        if e
          res.json({status: 500, reason: "Internal Server Error: #{e}"}, 500)
        else
          if not (userId in r.users)
            res.json({status: 403, reason: "Not authorized to view this event"}, 403)
          else
            res.json(r, 200)

###
  POST /events/message
  ReplicateEventMessage swapEventId, session
    This service triggers replications between users databases
    @todo make PUT
    @possibleName Replicant
    @param swapEventId {string} id of swap event to filter on
    @param session {cookie} authenicates user
    @method POST
    @url /events/message

    ids = GET /mapper/swapEventId
    src = getIdFromSession()
    ids.each (dst) -
    replicate src, dst, filter(swapEventId)
###
app.post '/events/message', (req, res) ->
  eventId = req.body.eventId
  debug "POST /events/message"
  debug "   eventId: #{eventId}"
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'}, 403)
    else
      src = r.userId
      getEventUsers {eventId}, (e, r) ->
        # 404 or 500
        if e then res.json(e, e.status)
        else
          if not (src in r.users)
            res.json({status: 403, reason: "Not authorized to write messages to this event"}, 403)
          else
            dsts = _.without(r.users, src)
            replicateMessages {src, dsts, eventId}, (e, r) ->
              if e
                res.json({status: 500, reason: "Internal Server Error: #{e}"}, 500)
              else
                res.json(r, 201)


# fire up HTTP server
app.listen(3000)

# fire up server listening to send out admin actions
listen()

module.exports = app
