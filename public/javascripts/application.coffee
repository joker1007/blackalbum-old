$().ready ->
  socket = io.connect 'localhost'
  socket.on 'save_entry', (data) ->
    $.jGrowl "Saved: #{data.name}"
  socket.on 'duplicate_entry', (data) ->
    $.jGrowl "Already Exist: #{data.name}"
  socket.on 'all_updated', (target) ->
    $.jGrowl "All Updated: #{target}"
  socket.on 'player_exit', (msg) ->
    $.jGrowl msg


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

