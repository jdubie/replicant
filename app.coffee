express = require('express')
_ = require('underscore')

{getUserIdFromSession} = require('./lib/replicant')
{createUser} = require('./lib/replicant')
{createEvent} = require('./lib/replicant')
{getEventUsers} = require('./lib/replicant')
{replicateMessages} = require('./lib/replicant')

app = express.createServer()
app.use(express.bodyParser())

# POST /users
app.post '/users', (req, res) ->
  console.log("POST /users")
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


# POST /events
app.post  '/events', (req, res) ->
  swapId = req.body.swapId
  console.log("POST /events")
  console.log("   swapId: #{swapId}")
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
  console.log("GET /events/members")
  console.log("   eventId: #{eventId}")
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

# POST /events/message
app.post '/events/message', (req, res) ->
  eventId = req.body.eventId
  console.log("POST /events/message")
  console.log("   eventId: #{eventId}")
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


# fire that baby up
app.listen(3000)

module.exports = app
