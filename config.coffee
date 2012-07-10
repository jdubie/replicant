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
module.exports.__defineGetter__ 'smtp', do ->
  inst = null
  () ->
    if inst == null
      debug 'creating smtp server connection'
      if process.env.PROD
        inst = nodemailer.createTransport 'SMTP',
          service: 'Gmail'
          auth:
            user: process.env.GMAIL_USER
            pass: process.env.GMAIL_PWD
      else
        inst = nodemailer.createTransport 'STMP',
          host: 'localhost'
          port: '2500' # 25 is priviledged port
    return inst
