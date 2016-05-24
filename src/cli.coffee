load  = require './loader'
fs = require('fs')

migrate = (args)->
  mig   = require './migrations'
  mig.up()

unmigrate = (args)->
  mig   = require './migrations'
  mig.down()

generate_migration = (args)->
  mig   = require './migrations'
  mig.generate(args[0])

fs = require('fs')
config = JSON.parse(fs.readFileSync(process.cwd() + '/plpl.json', 'utf8'))
process.env.DATABASE_URL ||= config.database_url
# console.log("CONFIG",config)

reload = (args)->
  console.log("Reloading #{config.entry}")
  plv8 = require('./plv8')
  plv8.execute load.scan(process.cwd() + '/' + config.entry)

compile = (args)->
  file = args[0]
  console.log("-- Compile #{config.entry}")
  sql =  load.scan(process.cwd() + '/' + config.entry)
  if file
    fs.writeFileSync(file, sql)
  else
    console.log(sql)

commands =
 compile:
   default:
     fn: compile
     args: ''
     desc: 'return sql string'
 reload:
   default:
     fn: reload
     args: ''
     desc: 'reload procedures'
   watch:
     fn: reload
     args: ''
     desc: 'watch src directory and update procs'
 migrate:
   default:
     fn: migrate
     args: ''
     desc: 'migrate up'
   down:
     fn: unmigrate
     args: ''
     desc: 'migrate down'
   new:
     fn: generate_migration
     args: '<migration_name>'
     desc: 'generate new migration'

print_usage = (commands)->
  for k,v of commands
    for sk, vv of v
      sk = '' if sk == 'default'
      console.log "\nplpl #{k} #{sk} #{vv.args}"
      console.log "  #{vv.desc}"
  console.log ""

exports.run = ()->
  cmd_nm = process.argv[2]
  if not cmd_nm
    print_usage(commands)

  subcmd_nm = process.argv[3]
  args = process.argv[4..-1]

  cmd = commands[cmd_nm]
  unless cmd
    console.log("Unknown command #{cmd_nm}")
    return
  subcmd = cmd[subcmd_nm]

  unless subcmd
    subcmd = cmd['default']
    args = [subcmd_nm].concat(args)

  unless subcmd
    console.log("Unknown sub-command #{subcmd_nm}")
    return

  subcmd.fn(args)
