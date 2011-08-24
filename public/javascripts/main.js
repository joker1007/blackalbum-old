(function() {
  $().ready(function() {
    $('a.movie-play').live('click', function(e) {
      var selected;
      e.preventDefault();
      selected = $('#player_select option:selected');
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        data: "pid=" + (selected.val()),
        success: function(movie) {
          return $.jGrowl("Start Play: " + movie.name);
        }
      });
    });
    $('a.book-play').live('click', function(e) {
      var selected;
      e.preventDefault();
      selected = $('#player_select option:selected');
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        data: "pid=" + (selected.val()),
        success: function(book) {
          return $.jGrowl("Start Play: " + book.name);
        }
      });
    });
    $('.paginator a, a.duplicate').live('click', function(e) {
      e.preventDefault();
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        data: "xhr=true",
        success: function(html) {
          var movies;
          movies = $('.movies');
          movies.fadeOut();
          movies.queue(function() {
            movies.html(html);
            return movies.dequeue();
          });
          return movies.queue(function() {
            movies.fadeIn();
            return movies.dequeue();
          });
        }
      });
    });
    $('form.search_form').live('submit', function(e) {
      var order;
      e.preventDefault();
      order = $('select#order option:selected').val();
      return $.ajax({
        type: 'POST',
        url: $(this).attr('action') + ("?xhr=true&order=" + order),
        data: $(this).serialize(),
        success: function(html) {
          var movies;
          movies = $('.movies');
          movies.fadeOut();
          movies.queue(function() {
            movies.html(html);
            return movies.dequeue();
          });
          return movies.queue(function() {
            movies.fadeIn();
            return movies.dequeue();
          });
        },
        error: function(msg) {
          return alert(msg);
        }
      });
    });
    $('div.movie-destroy a').live('click', function(e) {
      var confirm;
      e.preventDefault();
      confirm = window.confirm("本当に削除しますか？");
      if (confirm) {
        return $.ajax({
          type: 'POST',
          url: $(this).attr('href') + "?xhr=true",
          data: "_method=delete",
          success: function(id) {
            return $("div#movie-" + id).fadeOut();
          },
          error: function(msg) {
            return alert(msg);
          }
        });
      }
    });
    return $('div.book-destroy a').live('click', function(e) {
      var confirm;
      e.preventDefault();
      confirm = window.confirm("本当に削除しますか？");
      if (confirm) {
        return $.ajax({
          type: 'POST',
          url: $(this).attr('href') + "?xhr=true",
          data: "_method=delete",
          success: function(id) {
            return $("div#book-" + id).fadeOut();
          },
          error: function(msg) {
            return alert(msg);
          }
        });
      }
    });
  });
}).call(this);
