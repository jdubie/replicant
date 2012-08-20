debug = require('debug')('replicant/lib:mailer')
fs = require('fs')
path = require('path')
_ = require('underscore')
mustache = require('mustache')
config = require('../config')

###
  @name Mailer
  @description instances send out one type of email
###
class Mailer

  ###
    Creates a mailer with a default set of email headers

    @param templateName {string}
    @param headers {object.<string, string>} email headers
    @param data {object.<string, {string|array}> data for template
  ###
  constructor: ({@headers, @data, templateName}) ->
    debug 'creating mailer'
    @headers = @headers || {}
    @templatePath = path.join(__dirname, 'templates', templateName + '.mustache')

  send: ({headers, data}, callback) ->
    debug 'sending'
    callback = callback || () ->
    headers = headers || {}
    _.defaults(headers, @headers)

    ## generate templates and graft them onto headers
    @_getTemplates data, (err, templates) ->
      _.extend(headers, templates)

      ## actually send email
      debug "headers: #{JSON.stringify(headers)}"
      config.smtp.sendMail(headers, callback)

  _getTemplates: (data, callback) ->
    data = data || {}
    _.defaults(data, @data)

    fs.readFile @templatePath, 'utf-8', (err, templateHtml) ->
      html = mustache.to_html(templateHtml, data)
      callback(err, {html})


module.exports.Mailer = Mailer
