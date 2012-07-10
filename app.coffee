express = require('express')
_ = require('underscore')

{getUserIdFromSession} = require('./lib/replicant')
{createUser} = require('./lib/replicant')
{createEvent} = require('./lib/replicant')
{swapEventUsers} = require('./lib/replicant')
{replicate} = require('./lib/replicant')

app = express.createServer()


# POST /users
app.post '/users', (req, res) ->
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'})
    else
      userId = r.userId
      createUser {userId}, (e,r) ->
        if e
          res.json({status: 500, reason: "Internal Server Error: #{e}"})
        else
          res.json(r)


# POST /events
app.post '/events', (req, res) ->
  swapId = req.query.swapId
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'})
    else
      userId = r.userId
      createEvent {swapId, userId}, (e, r) ->
        if e then res.json({status: 500, reason: "Internal Server Error: #{e}"})
        else
          res.json(r)


# GET /events/members
app.get '/events/members', (req, res) ->
  # TODO: do we want it as a GET?
  eventId = req.query.eventId
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'})
    else
      userId = r.userId
      swapEventUsers {eventId}, (e, r) ->
        # there should only be responses, no errors
        if e
          res.json({status: 500, reason: "Internal Server Error: #{e}"})
        else
          if not (userId in r.users)
            res.json({status: 403, reason: "Not authorized to view this event"})
          else
            res.json(r)

# POST /events/message
app.post '/events/message', (req, res) ->
  eventId = req.query.eventId
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'})
    else
      src = r.userId
      swapEventUsers {eventId}, (e, r) ->
        # 404 or 500
        if e then res.json(e)
        else
          if not (src in r.users)
            res.json({status: 403, reason: "Not authorized to write messages to this event"})
          else
            dsts = _.without(r.users, src)
            replicate {src, dsts, eventId}, (e, r) ->
              if e
                res.json({status: 500, reason: "Internal Server Error: #{e}"})
              else
                res.json(r)


# fire that baby up
app.listen(3000)

module.exports = app
