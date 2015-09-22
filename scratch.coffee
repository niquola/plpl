plv8 = require('./src/plv8')
loader = require('./src/other_loader')

console.log plv8.execute 'select 1'

init_sql = loader.scan('../src/fhir/crud.coffee')

console.log(init_sql)
plv8.execute "CREATE SCHEMA IF NOT EXISTS fhir"
plv8.execute init_sql
