$().ready ->
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
  $('a.book-play').live 'click', (e) ->
    e.preventDefault()
    selected = $('#player_select option:selected')
    $.ajax {
      type: 'GET'
      url: $(this).attr 'href'
      data: "pid=#{selected.val()}"
      success: (book) ->
        $.jGrowl "Start Play: #{book.name}"
    }

  $('.paginator a, a.duplicate').live 'click', (e) ->
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

  $('div.movie-destroy a').live 'click', (e) ->
    e.preventDefault()
    confirm = window.confirm "本当に削除しますか？"
    if confirm
      $.ajax {
        type: 'POST'
        url: $(this).attr('href') + "?xhr=true"
        data: "_method=delete"
        success: (id) ->
          $("div#movie-#{id}").fadeOut()
        error: (msg) ->
          alert msg
      }
  $('div.book-destroy a').live 'click', (e) ->
    e.preventDefault()
    confirm = window.confirm "本当に削除しますか？"
    if confirm
      $.ajax {
        type: 'POST'
        url: $(this).attr('href') + "?xhr=true"
        data: "_method=delete"
        success: (id) ->
          $("div#book-#{id}").fadeOut()
        error: (msg) ->
          alert msg
      }

