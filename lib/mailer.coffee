debug = require('debug')('replicant:lib:mailer')
fs = require('fs')
path = require('path')
_ = require('underscore')
mustache = require('mustache')
config = require('../config')

module.exports.Mailer = class Mailer

  ###
    Creates a mailer with a default set of email headers

    @param templateName {string}
    @param headers {object.<string, string>} email headers
    @param data {object.<string, {string|array}> data for template
  ###
  constructor: ({@headers, @data, @templateName}) ->
    debug 'creating mailer'
    @headers = @headers || {}
    if @templateName?
      #@templateText = fs.readFileSync(path.join(__dirname, 'templates', 'text', @templateName + '.mustache'), 'utf-8')
      @templateHtml = fs.readFileSync(path.join(__dirname, 'templates', 'html', @templateName + '.mustache'), 'utf-8')

  send: ({headers, data}, callback) ->
    callback = callback || () ->
    headers = headers || {}
    _.defaults(headers, @headers)

    ## generate templates and graft them onto headers
    if @templateName?
      templates = @_getTemplates(data)
      _.extend(headers, templates)

    ## actually send email
    config.smtp.sendMail(headers, callback)

  _getTemplates: (data) ->
    data = data || {}
    _.defaults(data, @data)

    #text = mustache.to_html(@templateText, data)
    html = mustache.to_html(@templateHtml, data)
    #return {text,html}
    return {html}
