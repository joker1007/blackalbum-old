(function() {
  $().ready(function() {
    $("a.watch_destroy").live('click', function(e) {
      var confirm;
      e.preventDefault();
      confirm = window.confirm("本当に削除しますか？");
      if (confirm) {
        return $.ajax({
          type: 'POST',
          url: $(this).attr("href"),
          data: "_method=delete",
          success: function(watch) {
            return $("#watch-" + watch._id).fadeOut();
          },
          error: function(msg) {
            return alert(msg);
          }
        });
      }
    });
    $('a.watch_edit').live('click', function(e) {
      return open_form_dialog(this, e, {}, {
        success: function(watch) {
          return $("#watch-" + watch._id + " td.dir").text(watch.dir);
        },
        error: function(err) {
          return alert(err.responseText);
        }
      });
    });
    return $('a.new_watch').live('click', function(e) {
      e.preventDefault();
      $('#new_watch_form').dialog('open');
      return $('form#new_watch').bind('submit', function() {
        return false;
      });
    });
  });
}).call(this);
