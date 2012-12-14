KEYS =
  A:         65
  ZERO:      48
  NINE:      57
  LEFT:      37
  RIGHT:     39
  UP:        38
  DOWN:      40
  BACKSPACE:  8
  DELETE:    46

KEYS.isDigit = (keyCode) ->
  @ZERO <= keyCode <= @NINE

KEYS.isDirectional = (keyCode) ->
  keyCode in [@LEFT, @RIGHT, @UP, @DOWN]

GAP = ' '

no_ws = (string) ->
  string.replace(/\s+/g, '')

class PanField
  constructor: (@element) ->
    @element.on 'keydown', @keyDown
    @element.on 'keyup', @keyUp
    @element.on 'click', @click

  keyDown: (event) =>
    {keyCode, metaKey, ctrlKey, shiftKey, altKey} = event

    # cmd / ctrl + A (select all) should reset selection direction
    if (metaKey or ctrlKey) and keyCode is KEYS.A
      @selectAll event

    # cmd / ctrl, probably doing some action
    else if metaKey or ctrlKey
      -> # pass

    # ← ↑ → ↓
    else if KEYS.isDirectional keyCode
      switch keyCode
        when KEYS.LEFT
          if shiftKey and altKey
            @moveWordLeftAndModifySelection event
          else if shiftKey
            @moveLeftAndModifySelection event
          else if altKey
            @moveWordLeft event
          else
            @moveLeft event
        when KEYS.RIGHT
          if shiftKey and altKey
            @moveWordRightAndModifySelection event
          else if shiftKey
            @moveRightAndModifySelection event
          else if altKey
            @moveWordRight event
          else
            @moveRight event
        when KEYS.UP
          if shiftKey then @moveUpAndModifySelection event
          else @moveUp event
        when KEYS.DOWN
          if shiftKey then @moveDownAndModifySelection event
          else @moveDown event

    # ⌫
    else if keyCode is KEYS.BACKSPACE
      if altKey
        @deleteWordBackward event
      else if ctrlKey
        @deleteBackwardByDecomposingPreviousCharacter event
      else
        @deleteBackward event

    else if keyCode is KEYS.DELETE
      if altKey
        @deleteWordForward event
      else
        @deleteForward event

    # shift / option / alt, probably inserting something not a digit
    else if shiftKey or altKey
      event.preventDefault()

    # 0-9
    else if KEYS.isDigit keyCode
      @insertDigit event

    return null

  moveUp: (event) ->
    event.preventDefault()

    # 1234 5678  =>  1234 5678
    #   |---|        |
    @caret = start: 0, end: 0
    @selectionDirection = null

  moveUpAndModifySelection: (event) ->
    caret = @caret
    event.preventDefault()

    switch @selectionDirection
      when 'left', null
        # 1234 5678   =>   1234 5678
        #   <---|          <-----|
        caret.start = 0
      when 'right'
        # 1234 5678   =>   1234 5678
        #   |--->          <-|
        caret.end = caret.start
        caret.start = 0

    @caret = caret
    @selectionDirection = 'left'

  moveDown: ->
    end = @value.length
    event.preventDefault()

    # 1234 5678  =>  1234 5678
    #   |---|                |
    @caret = start: end, end: end
    @selectionDirection = null

  moveDownAndModifySelection: ->
    caret = @caret
    end = @value.length
    event.preventDefault()

    switch @selectionDirection
      when 'left'
        # 1234 5678  =>  1234 5678
        #   <---|              |->
        caret.start = caret.end
        caret.end = end
      when 'right', null
        # 1234 5678  =>  1234 5678
        #   |--->          |----->
        caret.end = end

    @caret = caret
    @selectionDirection = 'right'

  moveLeft: (event) ->
    caret = @caret
    event.preventDefault()

    if @hasSelection
      # 1234 5678  =>  1234 5678
      #   |--|           |
      caret.end = caret.start
    else
      # 1234 5678  =>  1234 5678
      #   |             |
      caret.start--
      caret.end--

    @caret = caret
    @selectionDirection = null if caret.start is caret.end

  moveWordLeft: (event) ->
    event.preventDefault()
    index = @lastWordBreakBeforeIndex @caret.start - 1
    @caret = start: index, end: index
    @selectionDirection = null

  moveWordLeftAndModifySelection: (event) ->
    caret = @caret
    event.preventDefault()

    switch @selectionDirection
      when 'left', null
        @selectionDirection = 'left'
        # 1234 5678  =>  1234 5678
        #      <-|       <------|
        caret.start = @lastWordBreakBeforeIndex caret.start - 1
      when 'right'
        # 1234 5678  =>  1234 5678
        #       |->            |
        caret.end = @lastWordBreakBeforeIndex caret.end
        caret.end = caret.start if caret.end < caret.start

    @caret = caret
    @selectionDirection = null if caret.start is caret.end

  moveLeftAndModifySelection: (event) ->
    caret = @caret
    event.preventDefault()

    switch @selectionDirection
      when 'left', null
        @selectionDirection = 'left'
        # 1234 5678  =>  1234 5678
        #   <---|         <----|
        caret.start--
      when 'right'
        # 1234 5678   =>   1234 5678
        #   |--->            |-->
        caret.end--

    @caret = caret
    @selectionDirection = null if caret.start is caret.end

  moveRight: (event) ->
    caret = @caret
    event.preventDefault()

    if @hasSelection
      # 1234 5678  =>  1234 5678
      #   |--|              |
      caret.start = caret.end
    else
      # 1234 5678  =>  1234 5678
      #   |               |
      caret.start++
      caret.end++

    @caret = caret
    @selectionDirection = null if caret.start is caret.end

  moveWordRight: (event) ->
    event.preventDefault()
    index = @nextWordBreakAfterIndex @caret.end
    @caret = start: index, end: index
    @selectionDirection = null

  moveWordRightAndModifySelection: (event) ->
    caret = @caret
    event.preventDefault()

    switch @selectionDirection
      when 'left'
        # 1234 5678  =>  1234 5678
        #   <---|             <|
        caret.start = @nextWordBreakAfterIndex caret.start
        caret.start = caret.end if caret.start > caret.end
      when 'right', null
        @selectionDirection = 'right'
        # 1234 5678  =>  1234 5678
        #   |--->         |------>
        caret.end = @nextWordBreakAfterIndex caret.end

    @caret = caret
    @selectionDirection = null if caret.start is caret.end

  moveRightAndModifySelection: (event) ->
    caret = @caret
    event.preventDefault()

    switch @selectionDirection
      when 'left'
        # 1234 5678  =>  1234 5678
        #   |---|           |--|
        caret.start++
      when 'right', null
        @selectionDirection = 'right'
        # 1234 5678  =>  1234 5678
        #   |---|         |-----|
        caret.end++

    @caret = caret
    @selectionDirection = null if caret.start is caret.end

  deleteBackward: (event) ->
    caret = @caret
    event.preventDefault()

    caret.start--

    @caret = caret
    @clearSelection()

  deleteWordBackward: (event) ->
    if @hasSelection
      return @deleteBackward event

    event.preventDefault()
    caret = @caret

    caret.start = @lastWordBreakBeforeIndex caret.start - 1

    @caret = caret
    @clearSelection()

  deleteBackwardByDecomposingPreviousCharacter: (event) ->
    @deleteBackward event

  deleteForward: (event) ->
    caret = @caret
    event.preventDefault()

    caret.end++

    @caret = caret
    @clearSelection()

  deleteWordForward: (event) ->
    if @hasSelection
      return @deleteForward event

    caret = @caret
    event.preventDefault()

    caret.end = @nextWordBreakAfterIndex caret.end

    @caret = caret
    @clearSelection()

  @::__defineGetter__ 'hasSelection', ->
    caret = @caret
    caret.start isnt caret.end

  @::__defineGetter__ 'wordBreakIndexes', ->
    result = [0]

    for index in @formatter.constructor.GAP_INDEXES
      result.push index + 1

    if result[result.length-1] isnt @value.length
      result.push @value.length

    return result

  lastWordBreakBeforeIndex: (index) ->
    indexes = @wordBreakIndexes
    result = indexes[0]

    for wordBreakIndex in indexes
      if index > wordBreakIndex
        result = wordBreakIndex
      else
        break

    return result

  nextWordBreakAfterIndex: (index) ->
    indexes = @wordBreakIndexes.reverse()
    result = indexes[0]

    for wordBreakIndex in indexes
      if index < wordBreakIndex
        result = wordBreakIndex
      else
        break

    return result

  clearSelection: ->
    caret = @caret
    value = @value

    # 12345678  =>  128
    #   |---|         |
    value = value.substring(0, caret.start) + value.substring(caret.end)
    caret.end = caret.start

    @value = value
    @caret = caret
    @selectionDirection = null

  selectAll: (event) ->
    # Let the browser act as normal, but also forget the selection direction.
    @selectionDirection = null

  keyUp: (event) =>
    caret = @caret
    value = @value

    @value = value
    @caret = caret

  click: =>
    @selectionDirection = null

  insertDigit: (event) ->
    if @hasSelection
      @clearSelection()

    if @value.length is @formatter.length
      event.preventDefault()

  selectionDirection: null

  on: (args...) ->
    @element.on args...

  off: (args...) ->
    @element.off args...

  @::__defineGetter__ 'text', ->
    @element.val()

  @::__defineSetter__ 'text', (text) ->
    @element.val(text)

  @::__defineGetter__ 'value', ->
    no_ws @element.val()

  @::__defineSetter__ 'value', (value) ->
    value = no_ws value

    value = @_formatter.format(value)

    @element.val(value)
    @element.trigger 'change'

  @::__defineGetter__ 'formatter', ->
    @_formatter

  @::__defineSetter__ 'formatter', (formatter) ->
    value = @value
    @_formatter = formatter
    @value = value

  @::__defineGetter__ 'caret', ->
    realCaret = @element.caret()
    left  = @text.substring(0, realCaret.start)
    leftPadding = left.length - no_ws(left).length
    rightPadding = leftPadding + realCaret.text.length - no_ws(realCaret.text).length

    valueCaret =
      start: realCaret.start - leftPadding
      end: realCaret.end - rightPadding

    return valueCaret

  @::__defineSetter__ 'caret', (caret) ->
    text = @text
    realCaret = start: 0, end: 0

    # go left until we've consumed enough non-whitespace characters
    nonWhitespaceCharacterCount = 0
    for i in [0..text.length] when text[i] isnt GAP
      if nonWhitespaceCharacterCount is caret.start
        realCaret.start = i

      if nonWhitespaceCharacterCount is caret.end
        realCaret.end = i
        break

      nonWhitespaceCharacterCount++

    if realCaret.start isnt realCaret.end and text[realCaret.end-1] is GAP
      realCaret.end--

    @element.caret(realCaret)

if module?
  module.exports = PanField
else if window?
  window.PanField = PanField
