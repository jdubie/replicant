express = require('express')
_ = require('underscore')

{getUserIdFromSession} = require('./lib/replicant')
{signup} = require('./lib/replicant')
{createSwapEvent} = require('./lib/replicant')
{swapEventUsers} = require('./lib/replicant')
{replicate} = require('./lib/replicant')
{listen} = require('./lib/adminNotifications')

app = express.createServer()

app.get '/signup', (req, res) ->
  if req.query.userId?
    userId = req.query.userId
    signup {userId}, (e,r) ->
      if e then res.json({status: 500, reason: "Internal Server Error: #{e}"})
      else res.json(r)
  else
    # TODO: getUserIdFromSession
    getUserIdFromSession headers: req.headers, (err, r) ->
      if err
        res.json({status: 403, reason: 'User must be logged in'})
      else
        userId = r.userId
        signup {userId}, (e,r) ->
          if e
            res.json({status: 500, reason: "Internal Server Error: #{e}"})
          else
            res.json(r)


app.get '/swapEvent', (req, res) ->
  swapId = req.query.swapId
  if req.query.userId?
    userId = req.query.userId
    createSwapEvent {swapId, userId}, (e, r) ->
      if e then res.json({status: 500, reason: "Internal Server Error: #{e}"})
      else
        res.json(r)
  else
    # TODO: getUserIdFromSession
    getUserIdFromSession headers: req.headers, (err, r) ->
      if err
        res.json({status: 403, reason: 'User must be logged in'})
      else
        userId = r.userId
        createSwapEvent {swapId, userId}, (e, r) ->
          if e then res.json({status: 500, reason: "Internal Server Error: #{e}"})
          else
            res.json(r)


app.get '/swapEventUsers', (req, res) ->
  eventId = req.query.eventId
  if req.query.userId?
    userId = req.query.userId
    swapEventUsers {eventId}, (e, r) ->
      # there should only be responses, no errors
      if e
        res.json({status: 500, reason: "Internal Server Error: #{e}"})
      else
        if not (userId in r.users)
          res.json({status: 403, reason: "Not authorized to view this event"})
        else
          res.json(r)
  else
    # TODO: getUserIdFromSession
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

app.get '/message', (req, res) ->
  eventId = req.query.eventId
  if req.query.userId?
    src = req.query.userId
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
  else
    # TODO: getUserIdFromSession
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


# fire up HTTP server
app.listen(3000)

# fire up server listening to send out admin actions
listen()

module.exports = app
