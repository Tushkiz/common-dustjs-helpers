class CommonDustjsHelpers
  @dust = null

  export_helpers_to: (dust)=>
    dust.helpers = @get_helpers(dust.helpers)
    CommonDustjsHelpers.dust = dust

  get_helpers: (helpers)=>
    helpers ?= {}
    helpers['if'] = @if_helper
    helpers['unless'] = @unless_helper
    helpers['upcase'] =  helpers['UPCASE']= @upcase_helper
    helpers['downcase'] = @downcase_helper
    helpers['titlecase'] = helpers['Titlecase'] = @titlecase_helper
    helpers['filter'] = @filter_helper
    helpers['count'] = @count_helper
    helpers['repeat'] = @repeat_helper
    helpers['first'] = @first_helper
    helpers['last'] = @last_helper
    helpers['even'] = @even_helper
    helpers['odd'] = @odd_helper
    helpers['sep'] = @classic_sep unless helpers['sep']? # restore default {@sep} if not found
    helpers['idx'] = @classic_idx unless helpers['idx']? # restore default {@idx} if not found
    return helpers

  _eval_dust_string: ( str, chunk, context )->
    if typeof str == "function"
      if str.length == 0
        str = str()
      else
       buf = ''
       (chunk.tap (data) -> buf += data; return '').render( str, context ).untap()
       str = buf
    return str

  classic_idx: (chunk, context, bodies)->
    return bodies.block(chunk, context.push(context.stack.index))

  classic_sep:(chunk, context, bodies)->
    if (context.stack.index == context.stack.of - 1)
      return chunk
    return bodies.block(chunk, context)

  # renders bodies.block iff b is true, bodies.else otherwise
  _render_if_else:(b, chunk, context, bodies, params)->
    if b is true
      chunk = chunk.render(bodies.block,context) if bodies.block?
    else
      chunk = chunk.render(bodies.else,context) if bodies.else?
    return chunk

  filter_helper: (chunk,context,bodies,params)=>
    filter_type = @_eval_dust_string(params.type,chunk,context) if params?.type?
    return chunk.capture bodies.block, context, (data,chunk)->
      if filter_type?
        data = CommonDustjsHelpers.dust.filters[filter_type](data)
      chunk.write(data)
      chunk.end()

  repeat_helper: (chunk,context,bodies,params)=>
    times = parseInt(@_eval_dust_string(params.times,chunk,context))
    if times? and not isNaN(times)
      context.stack.head?['$len'] = times
      for i in [0...times]
        context.stack.head?['$idx'] = i
        chunk = bodies.block(chunk, context.push(i, i, times));
      context.stack.head?['$idx'] = undefined
      context.stack.head?['$len'] = undefined
    return chunk

  upcase_helper: (chunk,context,bodies,params)=>
    return chunk.capture bodies.block, context, (data,chunk) ->
      chunk.write(data.toUpperCase())
      chunk.end()

  titlecase_helper: (chunk,context,bodies,params)=>
    return chunk.capture bodies.block, context, (data,chunk) ->
      chunk.write( data.replace(/([^\W_]+[^\s-]*) */g, ((txt)->txt.charAt(0).toUpperCase()+txt.substr(1))) )
      chunk.end()

  downcase_helper: (chunk,context,bodies,params)=>
    return chunk.capture bodies.block, context, (data,chunk) ->
      chunk.write(data.toLowerCase())
      chunk.end()

  # @first helper - evaluates the body iff the current element is the first in the list
  first_helper: (chunk,context,bodies,params)=>
    if context?.stack?.index?
      c = (context.stack.index is 0)
      return @_render_if_else(c, chunk, context, bodies, params)
    return chunk

  # @last helper - evaluates the body iff the current element is the last in the list
  last_helper: (chunk,context,bodies,params)=>
    if context?.stack?.index?
      c = (context.stack.index is (context.stack.of - 1))
      return @_render_if_else(c, chunk, context, bodies, params)
    return chunk

  # @odd helper - evaluates the body iff the index of the current element is odd (for zebra striping, for example)
  odd_helper: (chunk,context,bodies,params)=>
    if context?.stack?.index?
      c = (context.stack.index % 2 is 1)
      return @_render_if_else(c, chunk, context, bodies, params)
    return chunk

  # @even helper - evaluates the body iff the index of the current element is even (for zebra striping, for example)
  even_helper: (chunk,context,bodies,params)=>
    if context?.stack?.index?
      c = (context.stack.index % 2 is 0)
      return @_render_if_else(c, chunk, context, bodies, params)
    return chunk

  count_helper: (chunk,context,bodies,params)=>
    value = @_eval_dust_string(params.of,chunk,context)
    if value?.length?
      chunk.write(value.length)
    return chunk

  # {@if value=X matches=Y}
  if_helper: (chunk,context,bodies,params)=>
    execute_body = @_inner_if_helper(chunk,context,bodies,params)
    return @_render_if_else(execute_body,chunk,context,bodies,params)

  # {@unless value=X matches=Y}
  unless_helper: (chunk,context,bodies,params)=>
    execute_body = @_inner_if_helper(chunk,context,bodies,params)
    execute_body = not execute_body
    return @_render_if_else(execute_body,chunk,context,bodies,params)

  _inner_if_helper: (chunk,context,bodies,params)=>
    execute_body = false
    if params?
      if params.test?
        value = @_eval_dust_string(params.test,chunk,context)
      for c in [ 'count', 'count_of', 'count-of', 'countof' ]
        if params[c]?
          countof = @_eval_dust_string(params[c],chunk,context)
          if countof?.length?
            value = countof.length
      value ?= @_eval_dust_string(params.value,chunk,context)
      if value?
        if "#{value}" is "#{parseFloat(value)}"
          value = parseFloat(value)
        if params.matches?
          matches = @_eval_dust_string(params.matches,chunk,context)
          re = new RegExp(matches)
          execute_body = re.test(value)
        else if params['is']?
          isval = @_eval_dust_string(params['is'],chunk,context)
          if typeof value is 'number' and (not isNaN(parseFloat(isval)))
            isval = parseFloat(isval)
          execute_body = value is isval
        else if params['isnt']?
          isntval = @_eval_dust_string(params['isnt'],chunk,context)
          if typeof value is 'number' and (not isNaN(parseFloat(isntval)))
            isntval = parseFloat(isntval)
          execute_body = value isnt isntval
        else if params.above?
          above = @_eval_dust_string(params.above,chunk,context)
          if typeof value is 'number' and (not isNaN(parseFloat(above)))
            above = parseFloat(above)
          execute_body = value > above
        else if params.below?
          below = @_eval_dust_string(params.below,chunk,context)
          if typeof value is 'number' and (not isNaN(parseFloat(below)))
            below = parseFloat(below)
          execute_body = value < below
        else
          execute_body = value in [true,'true','TRUE','t','T',1,'1','on','ON','yes','YES','y','Y']
    return execute_body

exports = exports ? this
exports.CommonDustjsHelpers = CommonDustjsHelpers
