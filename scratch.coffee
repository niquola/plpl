plv8 = require('./src/plv8')
loader = require('./src/loader')

console.log plv8.execute 'select 1'

loader.scan('./scratch_code.coffee')

mod = require('./scratch_code.coffee')

mod.generate_table(plv8, 'users')

console.log plv8.execute 'select plv8_add(1, 3)'
console.log plv8.execute 'select generate_table($1)', ['musers']
