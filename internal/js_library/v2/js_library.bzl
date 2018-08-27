
"""js_library allows defining a set of javascript sources to be used with ts_devserver"""

load("@bazel_skylib//:lib.bzl", "paths")

def _write_config(ctx):
  output = ctx.actions.declare_file(paths.join(ctx.file._babelrc_tmpl.dirname, "_" + ctx.file._babelrc_tmpl.basename))
  ctx.actions.expand_template(
    output = output,
    template =  ctx.file._babelrc_tmpl,
    substitutions = {
        "TMPL_bin_dir_path": ctx.bin_dir.path,
        "TMPL_module_name": ctx.attr.module_name,
    }
  )
  return output

def _create_babel_args(ctx, config_path, out_files_extenstion):
  args = ctx.actions.args()
  args.add("--out-dir", ctx.bin_dir.path)
  args.add("--config-file", config_path)
  args.add("--out-files-extension", out_files_extenstion)
  args.add_all(ctx.files.srcs)
  return args

def _declare_babel_outputs(ctx, file_extenstion):
  return [ctx.actions.declare_file(src.basename[:-2] + file_extenstion) for src in ctx.files.srcs]

def _run_babel(ctx, inputs, outputs, args, env, mnemonic, description):
  ctx.actions.run(
    executable = ctx.executable._babel,
    inputs = inputs,
    outputs = outputs,
    arguments = [args],
    env = env,
    mnemonic = mnemonic,
    progress_message = "Compiling Javascript (%s) %s" % (description, ctx.label),
  )

def _babel_conversion(ctx, inputs, config, file_extenstion, env, mnemonic, description):
  outputs = _declare_babel_outputs(ctx, file_extenstion)
  args = _create_babel_args(ctx, config.path, file_extenstion)
  _run_babel(ctx, inputs, outputs, args, env, mnemonic, description)
  return outputs

def _amd_conversion(ctx, inputs, config):
  file_extenstion = "ajs"
  env = {
    "BAZEL_AMD_TARGET": "true",
  }
  return _babel_conversion(ctx, inputs, config, file_extenstion, env, "JsAmdCompile", "devmode")

def _es5_conversion(ctx, inputs, config):
  file_extenstion = "es5.js"
  env = {
    "BAZEL_ES5_TARGET": "true",
  }
  return _babel_conversion(ctx, inputs, config, file_extenstion, env, "JsEs5Compile", "prodmode")

def _collect_sources(ctx, es5_outputs, amd_outputs):
  amd_sources = depset(amd_outputs)
  es5_sources = depset(es5_outputs)
  es6_sources = depset(ctx.files.srcs)
  transitive_es5_sources = depset()
  transitive_es6_sources = depset()
  for dep in ctx.attr.deps:
    if hasattr(dep, "typescript"):
        transitive_es5_sources = depset(transitive = [
            transitive_es5_sources,
            dep.typescript.transitive_es5_sources,
        ])
        transitive_es6_sources = depset(transitive = [
            transitive_es6_sources,
            dep.typescript.transitive_es6_sources,
        ])

  return struct(
    amd_sources = amd_sources,
    es5_sources = es5_sources,
    transitive_es5_sources = depset(transitive = [transitive_es5_sources, es5_sources]),
    es6_sources = es6_sources,
    transitive_es6_sources = depset(transitive = [transitive_es6_sources, es6_sources])
  )


def _js_library(ctx):
  config = _write_config(ctx)
  inputs = ctx.files.srcs + ctx.files.data + [config]

  amd_outputs = _amd_conversion(ctx, inputs, config)
  es5_outputs = _es5_conversion(ctx, inputs, config)

  js_providers = _collect_sources(ctx, es5_outputs, amd_outputs)

  # Return legacy providers as ts_devserver still uses legacy format
  return struct(
    typescript = struct(
      es6_sources = js_providers.es6_sources,
      transitive_es6_sources = js_providers.transitive_es6_sources,
      # Note: this returning the amd sources here for ts_devserver compatibility, should be
      # js_porivders.es5_sources
      es5_sources = js_providers.amd_sources,
      transitive_es5_sources = js_providers.transitive_es5_sources,
    ),
    legacy_info = struct(
      files = js_providers.amd_sources,
      tags = ctx.attr.tags,
      module_name =  ctx.attr.module_name,
    ),
    providers = [
      DefaultInfo(
          files = depset(amd_outputs + es5_outputs),
          runfiles = ctx.runfiles(),
      ),
      OutputGroupInfo(
          es5_sources = js_providers.es5_sources,
          amd_sources = js_providers.amd_sources,
      ),
    ],
  )

js_library = rule(
    implementation = _js_library,
    attrs = {
        "srcs": attr.label_list(
            doc = """JavaScript source files from the workspace.
            These can use ES2015 syntax and ES Modules (import/export)""",
            allow_files = [".js"]
        ),
        "deps": attr.label_list(
            doc = """Other rules that produce JavaScript outputs, such as `ts_library`.""",
        ),
        "data": attr.label_list(
            doc = """Other files useful for babel such as .browserslistrc""",
            allow_files = True,
        ),
        "module_name": attr.string(),
        "module_root": attr.string(),
        "_babel": attr.label(
            executable = True,
            cfg="host",
            default = Label("//internal/js_library/v2:babel")
        ),
        "_babelrc_tmpl": attr.label(
            allow_single_file = True,
            default = Label("//internal/js_library/v2:babel.rc.js")
        ),
    },
)