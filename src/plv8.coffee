Client = require('pg-native')
global.INFO="INFO"
global.ERROR="ERROR"
global.DEBUG="DEBUG"

conn_string = process.env.DATABASE_URL

unless conn_string
  throw new Error("set connection string \n export DATABASE_URL=postgres://user:password@localhost:5432/test")

client = new Client
client.connectSync(conn_string)
module.exports =
  execute: ->
    client.querySync.apply(client, arguments).map (x) ->
      obj = {}
      for k of x
        if typeof x[k] == 'object'
          obj[k] = JSON.stringify(x[k])
        else
          obj[k] = x[k]
      obj
  elog: (x, msg) ->
    console.log "#{x}:", msg
    return

  quote_literal: (str)-> str && client.pq.escapeLiteral(str)
  nullable: (str)->
  quote_ident: (str)-> str && client.pq.escapeIdentifier(str)
