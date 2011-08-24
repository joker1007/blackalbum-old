(function() {
  $().ready(function() {
    var socket;
    socket = io.connect('localhost');
    socket.on('save_entry', function(data) {
      return $.jGrowl("Saved: " + data.name);
    });
    socket.on('duplicate_entry', function(data) {
      return $.jGrowl("Already Exist: " + data.name);
    });
    socket.on('all_updated', function(target) {
      return $.jGrowl("All Updated: " + target);
    });
    socket.on('player_exit', function(msg) {
      return $.jGrowl(msg);
    });
    $('a.updatedb').live('click', function(e) {
      e.preventDefault();
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        success: function(msg) {
          return $.jGrowl(msg);
        }
      });
    });
    return $('a.menu-item').click(function(e) {
      var order;
      e.preventDefault();
      order = $('select#order option:selected').val();
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        data: "xhr=true&order=" + order,
        success: function(html) {
          var main;
          main = $('#main');
          main.fadeOut();
          main.queue(function() {
            main.html(html);
            return main.dequeue();
          });
          return main.queue(function() {
            main.fadeIn();
            return main.dequeue();
          });
        }
      });
    });
  });
}).call(this);
