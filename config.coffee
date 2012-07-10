debug = require('debug')('replicant:config')
nodemailer = require('nodemailer')
user = 'hedwig'

# lazily instantiate db connection
module.exports.__defineGetter__ 'nano', do ->
  inst = null
  () ->
    if inst == null
      debug 'creating database connection'
      if process.env.PROD
        pwd = process.env.HEDWIG_PWD
        port = 5984
      else
        pwd = 'hedwig'
        port = 5985
      dbUrl = "http://#{user}:#{pwd}@localhost:#{port}"
      inst = require('nano')(dbUrl)
    return inst

# lazily instantiate SMTP transport
module.exports.emailPort = 8000 # 25 is priviledged port
module.exports.__defineGetter__ 'smtp', do ->
  inst = null
  () ->
    if inst == null
      if process.env.PROD
        debug 'creating smtp server connection to GMAIL'
        inst = nodemailer.createTransport 'SMTP',
          service: 'Gmail'
          auth:
            user: process.env.GMAIL_USER
            pass: process.env.GMAIL_PWD
      else
        debug 'creating smtp server connection to localhost'
        inst = nodemailer.createTransport 'SMTP',
          host: 'localhost'
          port: module.exports.emailPort
    return inst

