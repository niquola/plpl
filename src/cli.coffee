mig   = require './migrations'
load  = require './loader'

migrate = (args)->
  mig.up()

generate_migration = (args)->
  mig.generate(args[0])


reload = (args)->

commands =
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

  subcmd_nm = process.argv[3] || 'default'
  args = process.argv[4..-1]

  cmd = commands[cmd_nm]
  unless cmd
    console.log("Unknown command #{cmd_nm}")
    return
  subcmd = cmd[subcmd_nm]
  unless subcmd
    console.log("Unknown sub-command #{subcmd_nm}")
    return
  subcmd.fn(args)
