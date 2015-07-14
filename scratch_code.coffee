plv8_add = (a, b)-> a + b

module.exports.plv8_add = plv8_add
plv8_add.plv8 = 'plv8_add(a int, b int) RETURNS int'

generate_table = (plv8, nm)->
  tbl = plv8.quote_ident(nm)
  plv8.execute """
   DROP TABLE IF EXISTS #{tbl};
   CREATE TABLE #{tbl} (
     id serial PRIMARY KEY,
     data jsonb
   );
  """
  plv8.elog(INFO, "table #{tbl} generated")
  "table #{tbl} generated"

module.exports.generate_table = generate_table
generate_table.plv8 = 'generate_table(nm text) RETURNS text'
