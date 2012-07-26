debug = require('debug')('replicant:lib:adminNotifications')
{nano, smtp} = require('../config')
db = nano.db.use('lifeswap')
{Mailer} = require('./mailer')

headers =
  to: ['admin@thelifeswap.com']
  from: 'info@thelifeswap.com'
  subject: 'Swap review required'
templateName = 'swapReview'
reviewSwapMailer = new Mailer({headers,templateName})

feed = db.follow(since: 'now')
feed.filter = (doc, req) ->
  if doc.type == 'swap'
    return true
  return false

lastId = null

# @todo retry three times on error/failure
feed.on 'change', (change) ->
  id = change.id
  if id != lastId # weird issue with double notifications being sent
    # set email info
    lastId = id
    reviewSwapMailer.send {data: {id}}, (err, res) ->
      if err then debug "ERROR: #{JSON.stringify(err)}"
      else debug "mail successfully sent: #{JSON.stringify(res)}"

module.exports.listen = () ->
  feed.follow()
  debug 'starting feed listener'
