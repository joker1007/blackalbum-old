open_form_dialog = (sender, e, dialog_options, ajax_callbacks) ->
  e.preventDefault()
  $.ajax {
    type: 'GET'
    url: $(sender).attr 'href'
    success: (html) ->
      dom = $(html)
      submit = dom.find('input[type="submit"]')
      submit_value = submit.val()
      submit.hide()
      button_option = {}
      button_option[submit_value] = ->
        form = dom.children 'form'
        $.ajax {
          type: 'POST'
          url: form.attr 'action'
          data: form.serialize()
          success: ajax_callbacks.success
          error: ajax_callbacks.error
        }
        $(this).dialog 'close'
      button_option['キャンセル'] = ->
        $(this).dialog 'close'
      dom.dialog {
        autoOpen: true
        height: dialog_options?.height ? 300
        width: dialog_options?.width ? 600
        modal: true
        buttons: button_option
      }
      dom.find('form').bind 'submit', ->
        return false
  }

$().ready ->
  socket = io.connect 'localhost'
  socket.on 'save_movie', (data) ->
    $.jGrowl "Saved: #{data.name}"
  socket.on 'duplicate_movie', (data) ->
    $.jGrowl "Already Exist: #{data.name}"
  socket.on 'all_updated', (target) ->
    $.jGrowl "All Updated: #{target}"
  socket.on 'player_exit', (msg) ->
    $.jGrowl msg

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

  $('a.movie-play').live 'click', (e) ->
    e.preventDefault()
    selected = $('#player_select option:selected')
    $.ajax {
      type: 'GET'
      url: $(this).attr 'href'
      data: "pid=#{selected.val()}"
      success: (movie) ->
        $.jGrowl "Start Play: #{movie.name}"
    }

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


  $('a.updatedb').live 'click', (e) ->
    e.preventDefault()
    $.ajax {
      type: 'GET'
      url: $(this).attr 'href'
      success: (msg) ->
        $.jGrowl msg
    }

  $('a.menu-item').click (e) ->
    e.preventDefault()
    order = $('select#order option:selected').val()
    $.ajax {
      type: 'GET'
      url: $(this).attr 'href'
      data: "xhr=true&order=#{order}"
      success: (html) ->
        main = $('#main')
        main.fadeOut()
        main.queue ->
          main.html(html)
          main.dequeue()
        main.queue ->
          main.fadeIn()
          main.dequeue()
    }

  $('.paginator a').live 'click', (e) ->
    e.preventDefault()
    $.ajax {
      type: 'GET'
      url: $(this).attr 'href'
      data: "xhr=true"
      success: (html) ->
        movies = $('.movies')
        movies.fadeOut()
        movies.queue ->
          movies.html(html)
          movies.dequeue()
        movies.queue ->
          movies.fadeIn()
          movies.dequeue()
    }

  $('form.search_form').live 'submit', (e) ->
    e.preventDefault()
    order = $('select#order option:selected').val()
    $.ajax {
      type: 'POST'
      url: $(this).attr('action') + "?xhr=true&order=#{order}"
      data: $(this).serialize()
      success: (html) ->
        movies = $('.movies')
        movies.fadeOut()
        movies.queue ->
          movies.html(html)
          movies.dequeue()
        movies.queue ->
          movies.fadeIn()
          movies.dequeue()
      error: (msg) ->
        alert msg
    }
