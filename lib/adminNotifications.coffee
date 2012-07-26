debug = require('debug')('replicant:lib:adminNotifications')
config = require('../config')
db = config.nano.db.use('lifeswap')

# TODO make non-admin
debug 'creating database connection'
user = 'hedwig'
if process.env.PROD
  pwd = process.env.HEDWIG_PWD
  port = 5984
else
  pwd = 'hedwig'
  port = 5985


debug 'creating smtp server connection'
smtpTransport = nodemailer.createTransport "SMTP",
  service: 'Gmail'
  auth:
    user: process.env.GMAIL_USER
    pass: process.env.GMAIL_PWD
debug 'connected to smtp server'

mailOptions =
  from: "Notifications <notifications@thelifeswap.com>"
  to: "Jack <jack@thelifeswap.com>"
  subject: "New Swap Created"
  # text:
  # html:

headers =
  to: ['admin@thelifeswap.com', 'jdubie@stanford.edu']
  from: 'notifications@thelifeswap.com'
  subject: 'Swap review required'
templateName = 'swapReview'
reviewSwapMailer = new Mailer({headers, templateName})

feed = db.follow(since: 'now')

feed.filter = (doc, req) ->
  if doc.type == 'swap'
    return true
  return false

# @todo retry three times on error/failure
feed.on 'change', (change) ->
  # set email info
  mailOptions.text = "Approve/Deny new Swap here: http://lifeswap.co/admin/swaps/#{change.id}"

  debug "sending email with for swap with id: #{change.id}"
  smtpTransport.sendMail mailOptions, (err,res) ->
    if err
      debug "ERROR: #{JSON.stringify(err)}"
    else
      debug "mail successfully sent: #{JSON.stringify(res)}"

module.exports.start = () ->
  feed.follow()
  debug 'starting feed listener'
