$().ready ->
  socket = io.connect "http://localhost:8765/"
  socket.on 'save_movie', (data) ->
    $.jGrowl "Saved: #{data.name}"
  socket.on 'duplicate_movie', (data) ->
    $.jGrowl "Already Exist: #{data.name}"


  $("a.watch_destroy").live 'click', (e) ->
    e.preventDefault()
    confirm = window.confirm "本当に削除しますか？"
    if confirm
      $.ajax {
        type: 'POST'
        url: $(this).attr "href"
        data: "_method=delete"
        success: (watch)->
          $("tr#watch-#{watch._id}").fadeOut()
      }

  $('a.watch_edit').live 'click', (e) ->
    e.preventDefault()
    $.ajax {
      type: 'GET'
      url: $(this).attr 'href'
      success: (html) ->
        dom = $(html)
        dom.dialog {
          autoOpen: false
          height: 300
          width: 600
          modal: true
          buttons: {
            '更新' : ->
              thisObj = this
              form = dom.children 'form'
              $.ajax {
                type: 'POST'
                url: form.attr 'action'
                data: form.serialize()
                success: (watch) ->
                  $("#watch-#{watch._id} td.dir").text watch.dir
                  $(thisObj).dialog 'close'
                error: (err) ->
                  alert err.responseText
              }
            'キャンセル' : ->
              $(this).dialog 'close'
          }
        }
        dom.dialog 'open'
        dom.find('form').bind 'submit', ->
          return false
    }

  $('#new_watch_form').dialog {
    autoOpen: false
    height: 300
    width: 600
    modal: true
    buttons: {
      '追加' : ->
        thisObj = this
        form = $('form#new_watch')
        $.ajax {
          type: 'POST'
          url: form.attr 'action'
          data: form.serialize()
          success: (html) ->
            $('#watch_list').append html
            $(thisObj).dialog 'close'
          error: (err) ->
            alert err.responseText
        }
      'キャンセル' : ->
        $(this).dialog 'close'
    }
  }

  $('a.new_watch').click (e) ->
    e.preventDefault()
    $('#new_watch_form').dialog 'open'
    $('form#new_watch').bind 'submit', ->
      return false

  $('a.updatedb').click (e) ->
    e.preventDefault()
    $.ajax {
      type: 'GET'
      url: $(this).attr 'href'
      success: (msg) ->
        $.jGrowl msg
    }
