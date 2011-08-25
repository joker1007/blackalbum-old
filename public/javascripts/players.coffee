$().ready ->
  $('a.player_new').live 'click', (e) ->
    open_form_dialog this, e, {}, {
      success: (player) ->
        option = $("<option>").val(player._id).text(player.name)
        $('#player_select').append option
      error: (err) ->
        alert err.responseText
    }

  $('a.player_edit').live 'click', (e) ->
    selected = $('#player_select option:selected')
    $(this).attr "href", "/player/#{selected.val()}"
    open_form_dialog this, e, {}, {
      success: (player) ->
        option = $("<option>").val(player._id).text(player.name)
        selected.replaceWith option
        option.attr "selected", "selected"
      error: (err) ->
        alert err.responseText
    }

  $('a.player_destroy').live 'click', (e) ->
    e.preventDefault()
    selected = $('#player_select option:selected')
    confirm = window.confirm "本当に削除しますか？"
    if confirm
      $.ajax {
        type: 'POST'
        url: "/player/#{selected.val()}"
        data: "_method=delete"
        success: (player)->
          selected.remove()
      }

