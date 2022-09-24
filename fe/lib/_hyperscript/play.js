// register for the command keyword "foo"
_hyperscript.addCommand('play', function(parser, runtime, tokens) {

  if(!tokens.matchToken('play')) return

  const url = parser.requireElement('stringLike', tokens)

  let volume = 1.0
  if (tokens.matchToken("at")) {
    volume = parser.requireElement('expression', tokens)
    if (tokens.matchToken("volume")) {
    }
  }

  let delay = 0
  if (tokens.matchToken("after")) {
    delay = parser.requireElement('postfixExpression', tokens)
  }

  return {
    // All expressions needed by the command to execute.
    // These will be evaluated and the result will be passed back to us.
    args: [url, volume, delay],

    // Implement the logic of the command.
    // Can be synchronous or asynchronous.
    // @param {Context} context The runtime context, contains local variables.
    // @param {*} value The result of evaluating expr.
    op(context, url, volume, delay) {
      const el = new Audio(url)

      if (typeof volume === 'string') {
        volume = parseFloat(volume) / 100
      }

      el.volume = volume

      el.addEventListener('canplaythrough', () => {
        if (delay === 0) {
          el.play()
        } else {
          setTimeout(_ => el.play(), delay)
        }
      })
      // Return the next command to execute.
      return runtime.findNext(this)
    }
  }
})
