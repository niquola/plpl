plv8 = require('./plv8')
fs = require('fs')
path = require('path')

MIGRATION_REG = /^\d.*__.*/
parse_name = (x)-> {name: x}

ensure_migrations_table = ()->
  unless plv8.execute("select to_regclass('_migrations')")[0]['to_regclass']
    plv8.execute """
    create table if not exists _migrations (
      name text PRIMARY KEY,
      created_at timestamp default current_timestamp
    )
    """

past_migrations = ()->
  res = plv8.execute('SELECT * from _migrations')
  res.reduce ((a,x)-> a[x.name] = x; a), {}

existing_migrations = (dir)->
  files = fs.readdirSync(dir)
  for x in files.sort() when  x.match(MIGRATION_REG)
    m = parse_name(x)
    m.file = "#{dir}/#{x}"
    m

save_migration = (m)->
  plv8.execute 'INSERT INTO _migrations (name) VALUES ($1)', [m.name]

rm_migration = (m)->
  plv8.execute 'DELETE FROM _migrations WHERE name = $1', [m.name]

clear_migrations = ()->
  plv8.execute 'TRUNCATE _migrations'

migrate_up = (m)->
  mod = require(m.file)
  console.log("migrating #{m.name}...")
  if mod.up
    mod.up(plv8)
  else
    throw new Error("No exports.up for #{m.file}")
  save_migration(m)

migrate_down = (m)->
  mod = require(m.file)
  console.log("rolling back #{m.name}...")
  if mod.down
    mod.down(plv8)
  else
    throw new Error("No exports.down for #{m.file}")
  save_migration(m)

pending = (dir)->
  past = past_migrations()
  existing_migrations(dir).filter (x)-> not past[x.name]

ensure_migrations_dir = (dir)->
  dir = dir || process.env.MIGRATIONS_DIR
  unless dir
    dir = path.join(process.cwd(), "migrations")
  path.resolve(dir)

up = (dir)->
  dir = ensure_migrations_dir(dir)
  ensure_migrations_table()
  pnd = pending(dir)
  for m in pending(dir)
    migrate_up(m)
  if pnd.length == 0
    console.log "No pending migrations"
  else
    console.log "All migrations done!"

down = (dir)->
  dir = ensure_migrations_dir(dir)
  ensure_migrations_table()
  pnd = pending(dir)
  for m in pending(dir)
    migrate_down(m)
  if pnd.length == 0
    console.log "No pending migrations"
  else
    console.log "All migrations done!"

spit = (pth, cnt)->
  fd = fs.openSync(pth, 'a')
  fs.writeSync(fd, cnt)
  fs.closeSync(fd)

generate = (name, dir)->
  unless name
    throw new Error('name is required')
  dir = ensure_migrations_dir(dir)
  date = (new Date()).toISOString().replace(/\W+/g, "_")
  nm = "#{date}__#{name}.coffee"
  spit "#{dir}/#{nm}", ""

exports.up = up
exports.down = down
exports.generate = generate
