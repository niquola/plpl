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

module_code = (mod, code)->
  """
  _modules["#{mod.key}"] = {
    init:  function(){
      var exports = {};
      _current_stack.push({file: "#{mod.basename}", dir: "#{mod.dir}"})
      var module = {exports: exports};
      #{code}
      _current_stack.pop()
      return module.exports;
    }
  }
  """
parse_params = (src)->
  parts = src.split(")")[0].split("(")
  params = parts[parts.length - 1]
  params.split(",").map((x)-> x.trim())

zip = (a,b)->
  coll = if a.length > b.length then b else a
  coll.reduce(((acc, x, idx)-> acc.push([a[idx],b[idx]]); acc), [])

Module::_compile = (answer, filename) ->
  dir = path.dirname(filename)
  basename = path.basename(filename, '.coffee')
  module = {
    key: "#{dir}/#{basename}"
    filename: filename
    basename: basename
    dir: dir
    exports: {}
  }
  module.code = module_code(module, answer)
  plv8_exports[currentModule] = module
  res = oldcompile.apply(this, arguments)
  module.schema = @exports.plv8_schema
  for k,v of @exports when v.plv8_signature?
      sig = v.plv8_signature
      params = parse_params(v.toString())[1..-1]
      module.exports[k] ={
        name: k
        returns: sig[(sig.length - 1)]
        params: zip(params, sig)
        filename: filename
      }
  res

_isAbsolute = (pth)->
  path.resolve(pth) == path.normalize(pth)

generate_fn = (mod, name, info)->
  # todo validate params & signature
  params = (x.join(" ") for x in info.params).join(', ')
  pass_params = (x for [x,_] in info.params).join(', ')
  declaration = "#{mod.schema}.#{name}(#{params})"

  """
  ---
  CREATE OR REPLACE FUNCTION
  #{declaration}
  RETURNS #{info.returns} AS $$
    var mod = require("#{mod.filename}")
    return mod.#{name}(plv8, #{pass_params})
  $$ LANGUAGE plv8;
  ---
  """

scan = (pth) ->
  unless _isAbsolute(pth)
    pth = path.normalize(path.join(path.dirname(module.parent.filename), pth))

  currentModule = null
  Module._cache = {}
  plv8_exports = {}

  delete require.cache

  file = require(pth)

  deps = []
  fns = []
  for fl, info of plv8_exports
    console.log("Compile module #{fl}...")
    if info.schema
      console.log("in schema", info.schema)
      fns.push("CREATE SCHEMA IF NOT EXISTS #{info.schema};")
    deps.push(info.code)
    for k,v of info.exports
      console.log(" * fn #{k}...")
      fns.push(generate_fn(info, k,v))

  """
  CREATE OR REPLACE FUNCTION plv8_init() RETURNS text AS $$
    var _modules = {};
    var _current_stack = [];

    // modules start
    #{deps.join("\n")}
    // modules stop

    this.require = function(dep){
      var abs_path = dep.replace(/\\.coffee$/, '');
      var current = _current_stack[_current_stack.length - 1];
      if(dep.match(/^\\.\\.\\//)){
        var dir = current.dir.split('/');
        dir.pop();
        abs_path = dir.join('/') + '/' + dep.replace('../','');
      }
      else if(dep.match(/^\\.\\//)){
        abs_path = current.dir + '/' + dep.replace('./','');
      }
      // todo resolve paths
      var mod = _modules[abs_path]
      if(!mod){ throw new Error("No module " + abs_path + " while loading " + JSON.stringify(_current_stack)); }
      if(!mod.cached){ mod.cached = mod.init() }
      return mod.cached
    }
    this.modules = function(){
      var res = []
      for(var k in _modules){ res.push(k) }
      return res;
    }
    this.console = {
      log: function(x){ plv8.elog(NOTICE, x); }
    };
    return 'done'
  $$ LANGUAGE plv8 IMMUTABLE STRICT;

  #{fns.join("\n")}
  """

exports.scan = scan

