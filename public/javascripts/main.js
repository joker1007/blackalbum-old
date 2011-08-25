(function() {
  $().ready(function() {
    $('a.entry-play').live('click', function(e) {
      var selected;
      e.preventDefault();
      selected = $('#player_select option:selected');
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        data: "pid=" + (selected.val()),
        success: function(entry) {
          return $.jGrowl("Start Play: " + entry.name);
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
          var entries;
          entries = $('.entries');
          entries.fadeOut();
          entries.queue(function() {
            entries.html(html);
            return entries.dequeue();
          });
          return entries.queue(function() {
            entries.fadeIn();
            return entries.dequeue();
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
          var entries;
          entries = $('.entries');
          entries.fadeOut();
          entries.queue(function() {
            entries.html(html);
            return entries.dequeue();
          });
          return entries.queue(function() {
            entries.fadeIn();
            return entries.dequeue();
          });
        },
        error: function(msg) {
          return alert(msg);
        }
      });
    });
    $('div.entry-destroy a').live('click', function(e) {
      var confirm;
      e.preventDefault();
      confirm = window.confirm("本当に削除しますか？");
      if (confirm) {
        return $.ajax({
          type: 'POST',
          url: $(this).attr('href') + "?xhr=true",
          data: "_method=delete",
          success: function(id) {
            return $("div#entry-" + id).fadeOut();
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
