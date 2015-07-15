require('coffee-script/register')
path = require('path')
plv8 = require('./plv8')
Module = require("module")

currentModule = null
modules_idx = {}
plv8_exports = {}

oldrequire = Module::require

Module::require = (fl) ->
  currentModule = fl
  oldrequire.apply this, arguments

oldcompile = Module::_compile

Module::_compile = (answer, filename) ->
  modules_idx[currentModule] ={ filename: filename, code: answer}
  res = oldcompile.apply(this, arguments)
  for k,v of @exports when v.plv8?
      plv8_exports[k] ={fn: v, filename: filename}
  res

_isAbsolute = (pth)->
  path.resolve(pth) == path.normalize(pth)

scan = (pth) ->
  unless _isAbsolute(pth)
    pth = path.normalize(path.join(path.dirname(module.parent.filename), pth))

  currentModule = null
  Module._cache = {}
  modules_idx = {}
  plv8_exports = {}

  delete require.cache

  file = require(pth)

  modules_js = generate_modules(modules_idx)
  plv8.execute "CREATE EXTENSION IF NOT EXISTS plv8"
  for k,v of plv8_exports
    sql = generate_plv8_fn(pth, k, modules_js, v.fn)
    console.log('-- Load ', v.fn.plv8)
    #console.log(sql)
    plv8.execute(sql)
  file

generate_modules = (modules_idx)->
  mods = []
  for m,v of modules_idx
    console.log("dep: #{m}")
    mods.push "deps['#{m}'] = function(module, exports, require){#{v.code}};"
  mods.join("\n")

generate_plv8_fn = (mod, k, modules_js, fn)->
  def_fn = fn.plv8
  def_call = fn.toString().split("{")[0].split("function")[1].trim()

  """
  CREATE OR REPLACE FUNCTION #{def_fn} AS $$
  var deps = {}
  var cache = {}
  #{modules_js}
  var require = function(dep){
    if(!cache[dep]) {
      var module = {exports: {}};
      deps[dep](module, module.exports, require);
      cache[dep] = module.exports;
    }
    return cache[dep]
  }
  return require('#{mod}').#{k}#{def_call};
  $$ LANGUAGE plv8 IMMUTABLE STRICT;
  """
exports.scan = scan
