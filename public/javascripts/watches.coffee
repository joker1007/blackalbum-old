$().ready ->
  $("a.watch_destroy").live 'click', (e) ->
    e.preventDefault()
    confirm = window.confirm "本当に削除しますか？"
    if confirm
      $.ajax {
        type: 'POST'
        url: $(this).attr "href"
        data: "_method=delete"
        success: (watch)->
          $("#watch-#{watch._id}").fadeOut()
        error: (msg) ->
          alert msg
      }

  $('a.watch_edit').live 'click', (e) ->
    open_form_dialog this, e, {}, {
      success: (watch) ->
        $("#watch-#{watch._id} td.dir").text watch.dir
      error: (err) ->
        alert err.responseText
    }

  $('a.new_watch').live 'click', (e) ->
    e.preventDefault()
    $('#new_watch_form').dialog 'open'
    $('form#new_watch').bind 'submit', ->
      return false
